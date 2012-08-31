#!/bin/bash

user=
pass=
tmp=/tmp/asb-export

[ -f asb-config ] && . asb-config

request() {
	echo -n "Request.CurrentStatementPage=1"
	echo -n "&Request.SortColumnIndex=-1"
	echo -n "&Request.DirectionOfSort=Ascending"
	echo -n "&Request.AccountType=$2"
	echo -n "&Request.AccountKey=$1:$2"
	echo -n "&Request.FromDateMinValue=08/08/2010"
	echo -n "&Request.StatementMode=Search"
	echo -n "&Request.FromDate=$(date -v -3m +%d/%m/%Y)"
	echo -n "&Request.ToDate=$(date +%d/%m/%Y)"
	echo -n "&Request.DescriptionFilter="
	echo -n "&Request.DescriptionFilter_watermark=e.g. Countdown"
	echo -n "&Request.NumberOfTransactionsPerPage=250"
	echo -n "&Request.ExportFormat=OFX - MS Money"
	echo -n "&button=Export"
	echo
}

escape() {
	sed -e 's/ /+/g' -e 's|/|%2F|g' -e 's/:/%3A/'
}

curl() {
	/usr/bin/curl -s -L -b $tmp/cookies.txt -c $tmp/cookies.txt "$@"
}

mkdir -p $tmp
rm -f $tmp/*

echo 'Logging in to ASB'

curl -i -d "UserId=${user}&password=${pass}&Source=FNC" https://fnc.asbbank.co.nz/1/User/LogOn > $tmp/login.html

sed -ne 's|Location: https://fnc.asbbank.co.nz/\([0-9]\)*/\([0-9A-Z]*\)/Balances/Index|\1 \2|p' $tmp/login.html > $tmp/session.txt
dos2unix -q $tmp/session.txt
read server session < $tmp/session.txt

curl "https://fnc.asbbank.co.nz/$server/$session/Statement/Index" > $tmp/statement-form.html

gsed -ne 's|.*<option.*showExport="True".*value="\([0-9]*\):\([^"]*\)">\([^<]*\)</option>.*|\1 \2 \3|p' $tmp/statement-form.html > $tmp/accounts.txt

cat $tmp/accounts.txt | while read id type name; do
	echo "Exporting $name account"
	mkdir -p "accounts/$name"
	file="accounts/$name/$(date +%Y-%m-%d.%H%M).ofx"
	curl -d @<(request $id $type | escape) "https://fnc.asbbank.co.nz/$server/$session/statement" > "$file"
	grep -q '<OFX>' "$file"  || rm "$file"
done

rm -f $tmp/*
