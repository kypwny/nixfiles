#!/bin/bash

# Fetch XMR price from Kraken API

btc_price=$(curl -s "https://api.kraken.com/0/public/Ticker?pair=BTCUSD" | jq -r '.result.XXBTZUSD.c[0]' | awk '{printf "%.2f", $0}')
xmr_price=$(curl -s "https://api.kraken.com/0/public/Ticker?pair=XMRUSD" | jq -r '.result.XXMRZUSD.c[0]' | awk '{printf "%.2f", $0}')

if [ -n "$btc_price" ]; then
    echo "BTC: \$$btc_price   XMR: \$$xmr_price"
else
    echo "N/A"
fi
