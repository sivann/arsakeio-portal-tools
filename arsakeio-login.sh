#!/bin/bash

username="$1"
password="$2"

if [[ -z "$username" ]] ; then
    echo "$0 username password"
    exit
fi
if [[ -z "$password" ]] ; then
    echo "$0 username password"
    exit
fi

username_enc=$(echo -n  "$username" | jq -sRr @uri)
password_enc=$(echo -n "$password" | jq -sRr @uri)

echo "Processing $1"
arsakeiog_link_url='https://www.e-arsakeio.gr/'
arsakeiog_login_url='https://www.e-arsakeio.gr/start'
aade_debtinfo_url='https://www1.aade.gr/taxisnet/info/protected/displayDebtInfo.htm'
aade_debtinfo_url='https://www1.aade.gr/taxisnet/info/protected/displayDebtInfoAndPay.htm'

# remove cookies
rm -f cookie.txt

tmp=${username//[^a-zA-Z0-9]/}
tmp="out/$tmp"

mkdir -p $tmp
cd $tmp

# STEP 1, request login page
echo "Requesting login page"
curl -s -L "$arsakeiog_link_url" -o resp1.html --cookie-jar cookie.txt


csrf_token=$(grep qcsrfToken resp1.html|cut -d: -f2|awk -F"'" '{print $2}')
echo "Token: $csrf_token"
sleep 0.3

## STEP 2, POST login form

echo "Posting login"

curl -s -L "$arsakeiog_login_url" \
  -H 'authority: www.e-arsakeio.gr' \
  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
  -H 'accept-language: en-US,en;q=0.9,el;q=0.8,fr;q=0.7' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/x-www-form-urlencoded' \
  -H 'cookie: support_pdf=true; SimpleSAMLSessionID=230ac9b4157a99a77662f0d84771dc5d; PHPSESSID9aca0=itelc0u9iqvp4gi725vu2p61al' \
  -H 'origin: https://www.e-arsakeio.gr' \
  -H 'pragma: no-cache' \
  -H 'referer: https://www.e-arsakeio.gr/' \
  -H 'sec-ch-ua: "Chromium";v="118", "Google Chrome";v="118", "Not=A?Brand";v="99"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: document' \
  -H 'sec-fetch-mode: navigate' \
  -H 'sec-fetch-site: same-origin' \
  -H 'sec-fetch-user: ?1' \
  -H 'upgrade-insecure-requests: 1' \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36' \
  --cookie cookie.txt \
  --cookie-jar cookie.txt \
  --data-raw '_qf__login_form=&qfS_csrf='"${csrf_token}"'&login='"${username_enc}"'&password='"${password_enc}"'&submit_login=%CE%95%CE%AF%CF%83%CE%BF%CE%B4%CE%BF%CF%82' \
  > resp3.html

cat  resp3.html |tr '\n' ' '|sed -e 's,</\([^>]*\)>,\n</\1>\n,g' |sed 's/  */ /g' |grep '<a' > lessons.html

if grep -qi λάθος resp3.html ; then
    echo "Error logging in"
    exit
fi


kathikonta_url=$(grep -i  ΚΑΘΗΚ lessons.html |head -1| sed -e 's/.*href="\([^"]*\).*/\1/g' ) > kathikonta.html

echo "kathikonta url = $kathikonta_url"


# Get kathikonta diary:
echo "Getting kathikonta diary"
curl -s "${kathikonta_url}" \
  -H 'authority: www.e-arsakeio.gr' \
  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
  -H 'accept-language: en-US,en;q=0.9,el;q=0.8,fr;q=0.7' \
  -H 'cache-control: no-cache' \
  -H 'pragma: no-cache' \
  -H 'referer: https://www.e-arsakeio.gr/start' \
  -H 'sec-ch-ua: "Chromium";v="118", "Google Chrome";v="118", "Not=A?Brand";v="99"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: document' \
  -H 'sec-fetch-mode: navigate' \
  -H 'sec-fetch-site: same-origin' \
  -H 'upgrade-insecure-requests: 1' \
  --cookie cookie.txt \
  --cookie-jar cookie.txt \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36'  > diary.html

# Find active duty (one with red left border)
active_duty_url=$(cat diary.html |sed -e 's,</\([^>]*\)>,\n</\1>\n,g' |sed 's/  */ /g'| awk '/active-content/ {start=1} /href=/{if (start==1) lnk=1} {if (start==1 && lnk==1) {print $0; exit}}' | sed -e 's/.*href="\([^"]*\).*/\1/g' )

echo "Active duty url: ($active_duty_url)"

if [[ -z "$active_duty_url" ]] ; then
    echo "Active duty is empty (red left border), quitting"
    exit 1
fi

echo "Downloading active_duty"
curl  -s "$active_duty_url" \
  -H 'authority: www.e-arsakeio.gr' \
  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
  -H 'accept-language: en-US,en;q=0.9,el;q=0.8,fr;q=0.7' \
  -H 'cache-control: no-cache' \
  --cookie cookie.txt \
  --cookie-jar cookie.txt \
  -H 'pragma: no-cache' \
  -H 'referer: https://www.e-arsakeio.gr/cstart/course/7196' \
  -H 'sec-ch-ua: "Chromium";v="118", "Google Chrome";v="118", "Not=A?Brand";v="99"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: document' \
  -H 'sec-fetch-mode: navigate' \
  -H 'sec-fetch-site: same-origin' \
  -H 'sec-fetch-user: ?1' \
  -H 'upgrade-insecure-requests: 1' \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36'  \
  > active_duty.html


cat active_duty.html |sed -e 's,</\([^>]*\)>,\n</\1>\n,g' |sed 's/  */ /g' | sed '/^$/d'| \
   awk '/ef-content-area/ {start=1} /<.div>/ {if (start) stop=1} {if (stop) {print ; exit} ; if (start==1) print}' > lesson.html


echo "Sending email"
cat lesson.html  | s-nail -s 'Vassilis Lesson' -M "text/html"  sivann@gmail.com
echo "Done"

d=$(date +%FT%H%M%S)
d1=$(date +%F)

cd ..
