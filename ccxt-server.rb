#(c) 2019 Jan 26 by sacarlson_2000@yahoo.com aka sacarlson aka Scott Carlson
# middle restclient server to combine multiple ccxt feed prices
# it has minimal ccxt support with only the fetchTicker supported for a simulated custom exchange
# note I think all ccxt need to be changed to ccxt in all file names and references

# to start: bundle exec ruby ./ccxt-server.rb
# to minimaly test you can 
#curl -X POST http://localhost:8080/exchanges/custom/myccxt/fetchTicker -d '["XLM/USD"]'
# note: asset pair format is '["base/currency"]' that seems standard on ccxt-rest

# the plan is to have this server lookup a number of ccxt-rest or other built in feeds
# the returned number of feeds will then be weight averged out depending on the weight of what we
# think we know is the averge daily volume of the exchanges
# we can also setup a "fallback" mode that just uses one exchanges value that on failure will get another exchange feed 
# in an aranged order of best to worst feeds

# 

# I guess bundler/setup can be used optionaly instead of my way of starting the app, I've just never tried it
#require 'bundler/setup'
require 'sinatra'
require 'thin'
require './ccxt_lib.rb' 

# exchanges is an array of arrays that holds a group or two element arrays that contain the name of the exchange and it's trading weight
# example: ["kraken",75] would be the kraken exchange with trading weight of 75
# the weight value can be in percent or in the estimated daily volume of the exchanges.  I'm looking at percent as what I plan to use normally.
exchanges = [["kraken",66],["poloniex",33]]
# in this case with kraken at 66 and poloniex at 33 is because I know that kraken has about 2X the trading volume of poloniex so it
# should have two times the trading weight.  I guess the values of 2 and 1 would also work in this case.

#mode can be set to fallback or weighted_averge
# in fallback mode we start with the first exchange in the exchange array and ignore trading weight values
# if a feed fails it will just try and get the neet feed in line in the array list
# the first feed that works is returned as the result, if all fail then we return result as failure
#mode = "fallback"

# in the "weighted_averge" mode we get all the rate values from all the exchanges in the exchange array and do a total weighted averge 
# calculation on the group of values.  failed returns are just ignored and not added to the averge
mode = "weighted_averge"

#the min_total_average value is what we expect to return as failure if too many of the weighted averge return feeds fail.
# example if we have two feeds and one is weighted at 60 and one at 40 if we set min_total_averge of 50
# then we will return without error if the 60 weight returns ok or if both return ok, otherwise we return the feed as failed
# if we set min_total_averge to say 30 then if eather return without failure or both then that value will be returned, only if both fail will return a failure
min_total_weights = 60

#max_diff will look for the highest rate in the list compared to the lowest in the list and fail if the difference is above the max_diff
# we want this to be sure there is not a very big spread between the total set of exchange rates to triger a failure in that event.
# if set to 0 or undefined then we ignore max_diff, at this point we have no disable just set very high diff of like 1.0 to in a way disable
max_diff = 0.001

# set the listen port for the simulated ccxt-server
set :port, 8080

post '/exchanges/custom/myccxt/fetchTicker/?' do
    #puts "posted: #{params.keys[0]}"
    assetpair = params.keys[0]
    puts "assetpair: #{assetpair}"
    array = assetpair.split('/')
    # remove unneeded unprintable quotes and stuf from asset symbols
    base_code = array[0].delete('"').gsub(/[^[:print:]]/i, '')
    currency_code = array[1].delete('"').gsub(/[^[:print:]]/i, '')
    puts "base_code: #{base_code}" 
    puts "currency_code: #{currency_code}"   
    puts "mode: #{mode}"
    result = get_averge_feed(currency_code,base_code,exchanges,mode)
    send_result = {}
    send_result["bid"] = result["rate"]
    send_result["ask"] = result["rate"]
    send_result["last"] = result["rate"]
    send_result["info"] = result
    send_result["info"]["status"] = "pass"
    diff = (result["info"]["max_rate"] - result["info"]["min_rate"]).round(8)
    send_result["info"]["diff"] = diff
    if diff > max_diff
      send_result["info"]["status"] = "fail"
    end
    if min_total_weights < result["info"]["total_weights"]
      send_result["info"]["status"] = "fail"
    end
    # combine my ruby utility feed format to simplified ccxt standard format of:
    # {"symbol":"XLM/USD","timestamp":1547971723027,"datetime":"2019-01-20T08:08:43.027Z","high":0.109876,"low":0.106,"bid":0.10664,"ask":0.10681,"vwap":0.10762915,"open":0.10698,"close":0.106631,"last":0.106631,"baseVolume":3491949.44291745,"quoteVolume":375835.5503841787,"info":{"a":["0.10681000","9119","9119.000"],"b":["0.10664000","12000","12000.000"],"c":["0.10663100","1854.11799607"],"v":["1222498.78412874","3491949.44291745"],"p":["0.10736107","0.10762915"],"t":[165,718],"l":["0.10651000","0.10600000"],"h":["0.10780000","0.10987600"],"o":"0.10698000"}}
   # from this original utility feed format: {"service"=>"ccxt_kraken", "rate"=>"11.21007113", "base"=>"XLM", "currency_code"=>"USD"}
  # now changed the "rate" is just added to the standard return from ccxt to be compatible with my old feeds and make the standard ccxt format
  # available to new code that is writen and can make use of it   
    send_result.to_json
  # should see: {"bid":0.08189788,"ask":0.08189788,"last":0.08189788,"info":{"info":{"status":"pass","rates":{"kraken":"0.08172450","poloniex":"0.08224463"},"total_weights":99,"averge_rate":0.08189788,"max_rate":0.08224463,"min_rate":0.0817245},"bid":0.08189788,"ask":0.08189788,"last":0.08189788,"rate":0.08189788}}
end

post '/exchanges/custom/?' do
  # just fill responce to prevent error out on first exchange setup input
  puts "params.keys: #{params.keys}"
  # this simulated data bellow was collected from what was seen from a real ccxt server return
  simulated_sendback = '{"isBrowser":false,"isElectron":false,"isWebWorker":false,"isNode":true,"isWindows":false,"precisionConstants":{"ROUND":0,"TRUNCATE":1,"DECIMAL_PLACES":0,"SIGNIFICANT_DIGITS":1,"NO_PADDING":0,"PAD_WITH_ZERO":1},"ROUND":0,"TRUNCATE":1,"DECIMAL_PLACES":0,"SIGNIFICANT_DIGITS":1,"NO_PADDING":0,"PAD_WITH_ZERO":1,"timeout":10000,"is_browser":false,"is_electron":false,"is_web_worker":false,"is_node":true,"is_windows":false,"precision_constants":"~precisionConstants","options":{"limits":{"cost":{"min":{"BTC":0.0001,"ETH":0.0001,"XMR":0.0001,"USDT":1}}}},"fetchOptions":{},"userAgents":{"chrome":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36","chrome39":"Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36"},"headers":{},"proxy":"","origin":"*","minFundingAddressLength":1,"substituteCommonCurrencyCodes":true,"verbose":false,"debug":false,"journal":"debug.json","twofa":false,"secret":"nosecret","balance":{},"orderbooks":{},"tickers":{},"orders":{},"trades":{},"transactions":{},"fetch_options":"~fetchOptions","user_agents":"~userAgents","min_funding_address_length":1,"substitute_common_currency_codes":true,"id":"myccxt","name":"Poloniex","countries":["US"],"enableRateLimit":false,"rateLimit":1000,"certified":false,"has":{"CORS":false,"publicAPI":true,"privateAPI":true,"cancelOrder":true,"cancelOrders":false,"createDepositAddress":true,"createOrder":true,"createMarketOrder":false,"createLimitOrder":true,"deposit":false,"editOrder":true,"fetchBalance":true,"fetchBidsAsks":false,"fetchClosedOrders":"emulated","fetchCurrencies":true,"fetchDepositAddress":true,"fetchFundingFees":false,"fetchL2OrderBook":true,"fetchMarkets":true,"fetchMyTrades":true,"fetchOHLCV":true,"fetchOpenOrders":true,"fetchOrder":"emulated","fetchOrderBook":true,"fetchOrderBooks":false,"fetchOrders":"emulated","fetchTicker":true,"fetchTickers":true,"fetchTrades":true,"fetchTradingFees":true,"fetchTradingLimits":false,"withdraw":true,"fetchOrderTrades":true},"urls":{"logo":"https://user-images.githubusercontent.com/1294454/27766817-e9456312-5ee6-11e7-9b3c-b628ca5626a5.jpg","api":{"public":"https://poloniex.com/public","private":"https://poloniex.com/tradingApi"},"www":"https://poloniex.com","doc":["https://poloniex.com/support/api/","http://pastebin.com/dMX7mZE0"],"fees":"https://poloniex.com/fees"},"api":{"public":{"get":["return24hVolume","returnChartData","returnCurrencies","returnLoanOrders","returnOrderBook","returnTicker","returnTradeHistory"]},"private":{"post":["buy","cancelLoanOffer","cancelOrder","closeMarginPosition","createLoanOffer","generateNewAddress","getMarginPosition","marginBuy","marginSell","moveOrder","returnActiveLoans","returnAvailableAccountBalances","returnBalances","returnCompleteBalances","returnDepositAddresses","returnDepositsWithdrawals","returnFeeInfo","returnLendingHistory","returnMarginAccountSummary","returnOpenLoanOffers","returnOpenOrders","returnOrderTrades","returnTradableBalances","returnTradeHistory","sell","toggleAutoRenew","transferBalance","withdraw"]}},"requiredCredentials":{"apiKey":true,"secret":true,"uid":false,"login":false,"password":false,"twofa":false,"privateKey":false,"walletAddress":false},"currencies":{},"timeframes":{"5m":300,"15m":900,"30m":1800,"2h":7200,"4h":14400,"1d":86400},"fees":{"trading":{"taker":0.0025,"maker":0.0015},"funding":{"withdraw":{},"deposit":{}}},"parseJsonResponse":true,"skipJsonOnStatusCodes":[],"dontGetUsedBalanceFromStaleCache":false,"commonCurrencies":{"XBT":"BTC","BCC":"BTCtalkcoin","DRK":"DASH","AIR":"AirCoin","APH":"AphroditeCoin","BDG":"Badgercoin","BTM":"Bitmark","CON":"Coino","GOLD":"GoldEagles","GPUC":"GPU","HOT":"Hotcoin","ITC":"Information Coin","PLX":"ParallaxCoin","KEY":"KEYCoin","STR":"XLM","SOC":"SOCC","XAP":"API Coin"},"precisionMode":0,"limits":{"amount":{"min":1e-8,"max":1000000000},"price":{"min":1e-8,"max":1000000000},"cost":{"min":0,"max":1000000000}},"precision":{"amount":8,"price":8},"apikey":"nokey","hasCORS":false,"hasPublicAPI":true,"hasPrivateAPI":true,"hasCancelOrder":true,"hasCancelOrders":false,"hasCreateDepositAddress":true,"hasCreateOrder":true,"hasCreateMarketOrder":false,"hasCreateLimitOrder":true,"hasDeposit":false,"hasEditOrder":true,"hasFetchBalance":true,"hasFetchBidsAsks":false,"hasFetchClosedOrders":true,"hasFetchCurrencies":true,"hasFetchDepositAddress":true,"hasFetchFundingFees":false,"hasFetchL2OrderBook":true,"hasFetchMarkets":true,"hasFetchMyTrades":true,"hasFetchOHLCV":true,"hasFetchOpenOrders":true,"hasFetchOrder":true,"hasFetchOrderBook":true,"hasFetchOrderBooks":false,"hasFetchOrders":true,"hasFetchTicker":true,"hasFetchTickers":true,"hasFetchTrades":true,"hasFetchTradingFees":true,"hasFetchTradingLimits":false,"hasWithdraw":true,"hasFetchOrderTrades":true,"tokenBucket":{"refillRate":0.001,"delay":1,"capacity":1,"defaultCost":1,"maxCapacity":1000},"web3":{"currentProvider":{"host":"http://localhost:8545","timeout":0,"connected":false},"_requestManager":{"provider":"~web3~currentProvider","providers":{},"subscriptions":{}},"givenProvider":null,"providers":"~web3~_requestManager~providers","_provider":"~web3~currentProvider","version":"1.0.0-beta.34","utils":{"unitMap":{"noether":"0","wei":"1","kwei":"1000","Kwei":"1000","babbage":"1000","femtoether":"1000","mwei":"1000000","Mwei":"1000000","lovelace":"1000000","picoether":"1000000","gwei":"1000000000","Gwei":"1000000000","shannon":"1000000000","nanoether":"1000000000","nano":"1000000000","szabo":"1000000000000","microether":"1000000000000","micro":"1000000000000","finney":"1000000000000000","milliether":"1000000000000000","milli":"1000000000000000","ether":"1000000000000000000","kether":"1000000000000000000000","grand":"1000000000000000000000","mether":"1000000000000000000000000","gether":"1000000000000000000000000000","tether":"1000000000000000000000000000000"}},"eth":{"currentProvider":"~web3~currentProvider","_requestManager":{"provider":"~web3~currentProvider","providers":"~web3~_requestManager~providers","subscriptions":{}},"givenProvider":null,"providers":"~web3~_requestManager~providers","_provider":"~web3~currentProvider","defaultAccount":null,"defaultBlock":"latest","net":{"currentProvider":"~web3~currentProvider","_requestManager":{"provider":"~web3~currentProvider","providers":"~web3~_requestManager~providers","subscriptions":{}},"givenProvider":null,"providers":"~web3~_requestManager~providers","_provider":"~web3~currentProvider"},"accounts":{"currentProvider":"~web3~currentProvider","_requestManager":{"provider":"~web3~currentProvider","providers":"~web3~_requestManager~providers","subscriptions":{}},"givenProvider":null,"providers":"~web3~_requestManager~providers","_provider":"~web3~currentProvider","_ethereumCall":{},"wallet":{"_accounts":"~web3~eth~accounts","length":0,"defaultKeyName":"web3js_wallet"}},"personal":{"currentProvider":"~web3~currentProvider","_requestManager":{"provider":"~web3~currentProvider","providers":"~web3~_requestManager~providers","subscriptions":{}},"givenProvider":null,"providers":"~web3~_requestManager~providers","_provider":"~web3~currentProvider","net":{"currentProvider":"~web3~currentProvider","_requestManager":{"provider":"~web3~currentProvider","providers":"~web3~_requestManager~providers","subscriptions":{}},"givenProvider":null,"providers":"~web3~_requestManager~providers","_provider":"~web3~currentProvider"},"defaultAccount":null,"defaultBlock":"latest"},"abi":{"_types":[{},{},{},{},{},{},{}]},"compile":{}},"shh":{"currentProvider":"~web3~currentProvider","_requestManager":{"provider":"~web3~currentProvider","providers":"~web3~_requestManager~providers","subscriptions":{}},"givenProvider":null,"providers":"~web3~_requestManager~providers","_provider":"~web3~currentProvider","net":{"currentProvider":"~web3~currentProvider","_requestManager":{"provider":"~web3~currentProvider","providers":"~web3~_requestManager~providers","subscriptions":{}},"givenProvider":null,"providers":"~web3~_requestManager~providers","_provider":"~web3~currentProvider"}},"bzz":{"givenProvider":null,"currentProvider":null}}}'
# for now just send what we saw recieved in POST, not sure we need the above returned in some cases or even if it would work if we did send it.
# for my needs this is ok as my code doesn't use any of the returned info above
params.keys
end
