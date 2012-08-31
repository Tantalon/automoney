#!/bin/bash

user=
pass=
# The code in the URL identifying your account
person_code=
# A space separated list of accounts to import, must match both exported account name, and Xero account name
accounts=Cheque
# Xero does browser detection. and changes the content accordingly. We're using Chrome here.
useragent='Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.83 Safari/537.1'
tmp=/tmp/xero-import

[ -f xero-config ] && . xero-config

curl() {
	/usr/bin/curl -i -L -s -b $tmp/xero-cookies.txt -c $tmp/xero-cookies.txt --user-agent "$useragent" "$@"
}

urlencode() {
	sed -e 's|\+|%2B|g'
}

export tmp

mkdir -p $tmp
rm -f $tmp/*

echo 'Logging in to Xero'

curl "https://login.xero.com/?bhjs=-1" > $tmp/xero-page1.html

sed -ne 's|.*<input name="__RequestVerificationToken".*value="\([^"]*\)".*|\1|p' $tmp/xero-page1.html | urlencode > $tmp/xero-request-token.txt
dos2unix -q $tmp/xero-request-token.txt
read reqtoken < $tmp/xero-request-token.txt
[ $reqtoken ] || exit 1

curl -d "userName=${user}&password=${pass}&fragment=&__RequestVerificationToken=${reqtoken}" "https://login.xero.com/" > $tmp/xero-page2.html

sed -ne 's|.*applicationToken=\([a-z0-9]*\).*|\1|p' $tmp/xero-page2.html | head -1 | urlencode > $tmp/xero-app-token.txt
dos2unix -q $tmp/xero-app-token.txt
read apptoken < $tmp/xero-app-token.txt
[ $apptoken ] || exit 1

curl "https://login.xero.com/?applicationToken=${apptoken}&redirectCount=1&bhjs=-1" > $tmp/xero-page3.html

sed -ne 's|.*applicationToken=\([a-z0-9]*\).*|\1|p' $tmp/xero-page3.html | head -1 | urlencode > $tmp/xero-app-token.txt
dos2unix -q $tmp/xero-app-token.txt
read apptoken < $tmp/xero-app-token.txt
[ $apptoken ] || exit 1

curl "https://login.xero.com/?applicationToken=${apptoken}&redirectCount=1&bhjs=-1" > $tmp/xero-page4.html

for account in $accounts; do
	# Look for the latest account file from today
	file=$(ls -1t accounts/Cheque/$(date +%Y-%m-%d).*.ofx 2>/dev/null | head -1)
	[ $file ] || continue

	# Import the account
	echo Importing $account from $file
	curl --header 'Expect:' --form "bankFile=@$file" "https://personal.xero.com/$person_code/Import/LoadBankStatement/Cheque" > $tmp/xero-import-$account.html

	# Display the results
	sed -ne 's|.*"ImportResultMessage":"\([^"]*\)".*|\1|p' $tmp/xero-import-$account.html | sed -e 's|\\u003c|<|g' -e 's|\\u003e|>|g' -e 's|</p>|.|' -e 's|<[^>]*>||g'

done

rm -f $tmp/*
