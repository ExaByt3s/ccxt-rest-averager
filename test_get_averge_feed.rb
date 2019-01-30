#!/usr/bin/ruby
#(c) 2019 jan 26. by sacarlson  sacarlson_2000@yahoo.com aka Scott Carlson aka scotty.surething...
# test of get_averge_feed  function
# to start app for test: bundler exec ruby ./test_get_averge_feed.rb
# another method to test the function with ccxt-server using curl:
# curl -X POST http://localhost:8080/exchanges/custom/myccxt/fetchTicker -d '["XLM/USD"]'

require './ccxt_lib.rb' 

# standard ccxt server
   $ccxt_config["url"] =  "http://localhost:3000" 
   currency_code = "USD"
   base_code = "XLM"  

mode = "weighted_averge"
#mode = "fallback"
exchanges = [["kraken",66],["poloniex",33]]
#exchanges = [["kraken",66]]



 puts "results: #{ get_averge_feed(currency_code,base_code,exchanges,mode)}"

# results:
# {"info"=>{"status"=>"pass", "rates"=>{"kraken"=>"0.08082300", "poloniex"=>"0.08135490"}, "total_weights"=>99, "averge_rate"=>0.0810003, "max_rate"=>0.0813549, "min_rate"=>0.080823}, "bid"=>0.0810003, "ask"=>0.0810003, "last"=>0.0810003, "rate"=>0.0810003}
