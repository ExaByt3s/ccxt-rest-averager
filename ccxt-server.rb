#(c) 2019 Jan 26 by sacarlson_2000@yahoo.com aka sacarlson aka Scott Carlson
# middle restclient server to combine multiple ccxt-rest feed prices
# it has minimal ccxt support with only the fetchTicker supported for a simulated custom exchange feed
# this version now tested as working as a simulated feed for the kelp trading bot

# to start: bundle exec ruby ./ccxt-server.rb

# to minimaly test at default settings you can 
#curl -X POST http://localhost:3000/exchanges/binance/binance/fetchTicker -d '["XLM/USD"]'
# note: asset pair format is '["base/currency"]' that seems standard on ccxt-rest
# also note in my code if an unsupported reversed pair is used like ["USD/XLM"] we will auto reverse to get feed here and reverse back the corrected results

# This server looks up a number of ccxt-rest or other built in feeds
# the returned number of feeds will then be weight averged out depending on the weight of what we
# think we know is the averge daily volume of the exchanges
# we can also setup a "fallback" mode that just uses one exchanges value that on failure will attemp to get another exchange feed 
# in an aranged order of best to worst feeds


# I guess bundler/setup can be used optionaly instead of my way of starting the app, I've just never tried it
#require 'bundler/setup'
require 'sinatra'
require 'thin'
require './ccxt_lib.rb' 

# exchanges is an array of arrays that holds a group or two element arrays that contain the name of the exchange and it's trading weight.
# example: ["kraken",75] would be the kraken exchange with trading weight of 75
# the weight value can be in percent or in the estimated daily volume of the exchanges.  I'm looking at percent as what I plan to use normally.
exchanges = [["kraken",66],["poloniex",33]]
# in this case with kraken at 66 and poloniex at 33 is because I know that kraken has about 2X the trading volume of poloniex so it
# should have two times the trading weight.  I guess the values of 2 and 1 would also work in this case.

# on kelp we see: /exchanges/binance/binance/fetchTicker
#ccxt_exchange_name is the simulated exchange that the ccxt-server responds, binance is set as default to support kelp using binance
ccxt_exchange_name = "binance"
#ccxt_exchange_name = "custom"

#ccxt_exchange_account is the simulated exchange account used by the ccxt-server default is binance that is supported account name used in kelp for binance off the shelf
ccxt_echange_account = "binance"
#ccxt_echange_account = "myccxt"

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
#set :port, 8080
# to mimic the real ccxt-rest server default we need to set to port 3000
# remember to set the real ccxt-rest to port 3030 when that is started with ENV change to PORT=3030
# it seems Kelp is hard coded to port 3000 so I guess changing here and ccxt-rest is easiest for now
set :port, 3000

#end config settings *************************************************************************

# post '/exchanges/binance/binance/loadMarkets/?' do
post '/exchanges/' + ccxt_exchange_name +'/' + ccxt_echange_account + '/loadMarkets/?' do
  headers['Content-Type'] = 'application/json'
  puts "posted_c params,keys #{params.keys}"
  erb :loadmarkets
end


get '/exchanges' do
   headers['Content-Type'] = 'application/json'
   #task = param[:task]
   puts "params.keys #{params.keys}"
   puts "params[:task] #{params[:task]}"
'["_1broker","_1btcxe","acx","allcoin","anxpro","anybits","bibox","bigone","binance","bit2c","bitbank","bitbay","bitfinex","bitfinex2","bitflyer","bithumb","bitkk","bitlish","bitmarket","bitmex","bitsane","bitso","bitstamp","bitstamp1","bittrex","bitz","bl3p","bleutrade","braziliex","btcalpha","btcbox","btcchina","btcexchange","btcmarkets","btctradeim","btctradeua","btcturk","btcx","bxinth","ccex","cex","chbtc","chilebit","cobinhood","coinbase","coinbasepro","coincheck","coinegg","coinex","coinexchange","coinfalcon","coinfloor","coingi","coinmarketcap","coinmate","coinnest","coinone","coinsecure","coinspot","cointiger","coolcoin","crypton","cryptopia","deribit","dsx","ethfinex","exmo","exx","fcoin","flowbtc","foxbit","fybse","fybsg","gatecoin","gateio","gdax","gemini","getbtc","hadax","hitbtc","hitbtc2","huobi","huobicny","huobipro","ice3x","independentreserve","indodax","itbit","jubi","kraken","kucoin","kuna","lakebtc","lbank","liqui","livecoin","luno","lykke","mercado","mixcoins","negociecoins","nova","okcoincny","okcoinusd","okex","paymium","poloniex","qryptos","quadrigacx","quoinex","rightbtc","southxchange","surbitcoin","theocean","therock","tidebit","tidex","urdubit","vaultoro","vbtc","virwox","wex","xbtce","yobit","yunbi","zaif","zb"]'
end


#get '/exchanges/binance' do
get '/exchanges/' + ccxt_exchange_name do
  headers['Content-Type'] = 'application/json'
'["binance"]'
end

#get '/exchanges/binance/binance' do
get '/exchanges/' + ccxt_exchange_name + '/' + ccxt_echange_account  do
  headers['Content-Type'] = 'application/json'
  erb :binance_binance
end

#just to see any attempts of unsupported gets
get '/:task' do
  headers['Content-Type'] = 'application/json'
  puts ":task params.keys #{params.keys}"
  puts "params[:task] #{params[:task]}"
  'at_task'
end

#post '/exchanges/binance/binance/fetchTicker/?' do
post '/exchanges/' + ccxt_exchange_name +'/' + ccxt_echange_account + '/fetchTicker/?' do
    headers['Content-Type'] = 'application/json'
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

#post '/exchanges/binance/?' do
post '/exchanges/' + ccxt_exchange_name + '/?' do
  headers['Content-Type'] = 'application/json'
  # view params passed in post
  puts "params.keys: #{params.keys}"
  # use simulated binance return found in ./views/setup_binance.erb file that is pointed to bellow
  # this simulated data bellow was collected from what was seen from a real ccxt binance setup server return
  erb :setup_binance
end
