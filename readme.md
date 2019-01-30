## ccxt-rest-averager
ccxt-rest-averager is a middleware server that makes use of the original ccxt-rest server https://github.com/franz-see/ccxt-rest to read multiple supported price feeds from any number of crypto exchanges and combines the weighted averge price of all the prices recieved.  It then outputs this weighted averge feed in the same format as ccxt-rest server does just on another port on the same system.  This allows for any software that uses the ticker data from a ccxt-rest server to use custom averged feed data instead.  We also added a redundancy "fallback" mode that just reads a group of exchange feeds and returns the first working feed found.  This was really written to support Kelp a stellar.org trading bot that optionaly makes use of the ccxt-rest as a feed point.

## Configure settings
At this point the settings are just hard coded into the ./ccxt-server.rb app.  Maybe at some point we will create a readable config file but this was just a quick hack for what we needed at the time.
the values to change are:

### exchanges
exchanges is an array of arrays that holds a group or two element arrays that contain the name of the exchange and it's trading weight
example: ["kraken",75] would be the kraken exchange with trading weight of 75
the weight value can be in percent or in the estimated daily volume of the exchanges.  I'm looking at percent as what I plan to use normally.
exchanges = [["kraken",66],["poloniex",33]]
in this case with kraken at 66 and poloniex at 33 is because I know that kraken has about 2X the trading volume of poloniex so it
should have two times the trading weight.  I guess the values of 2 and 1 would also work in this case.
for details on what exchanges are available see the ccxt-rest docs at https://github.com/franz-see/ccxt-rest

### mode
in the default "weighted_averge" mode we get all the rate values from all the exchanges in the exchange array and do a total weighted averge 
calculation on the group of values returned.  failed returns are just ignored and not added to the averge. a failed return is also not added to the total_average value that is returned.
mode = "weighted_averge"

mode can also be set to "fallback
in fallback mode we start with the first exchange in the exchange array and ignore trading weight values
if a feed fails it will just try and get the neet feed in line in the array list
the first feed that works is returned as the result, if all fail then we return result as failure
mode = "fallback"

### min_total_average
the min_total_average value is what we expect to return as failure if too many of the weighted averge return feeds fail.
example if we have two feeds and one is weighted at 60 and one at 40 if we set min_total_averge of 50
then we will return without error if the 60 weight returns ok or if both return ok, otherwise we return the feed as failed
if we set min_total_averge to say 30 then if eather return without failure or both then that value will be returned, only if both fail will return a failure
min_total_weights = 60

### max_diff
max_diff will look for the highest rate in the list compared to the lowest in the list and fail if the difference is above this max_diff
we want this to be sure there is not a very big spread between the total set of exchange rates to triger a failure in that event.
at this point we have no disable for this so just set very high diff of like 1.0 to in a way disable this failure
max_diff = 0.001

### set :port
set the listen port for the simulated ccxt-server
set :port, 8080

### set :port pointing to real ccxt-rest
I should note at present we just hard coded the port address that points to the real ccxt-rest server.  I should assume at some point this might need to be changed.  To modify this value see value within file ccxt_lib.rb
$ccxt_config["url"] =  "http://localhost:3000"

the url:port points to the port you have the real ccxt-rest server running

## To install
git clone ccxt-rest-averager
cd ./ccxt-rest-averager
setup rbenv first (google it)
rbenv install 2.4.3
gem install bundler
bundler install

## To start restclient server
cd ./ccxt-rest-averger
bundle exec ruby ./ccxt-server.rb

## Requirements
tested with ruby version 2.4.3 with rbenv
ran on Linux mint system. not tested on any other platforms but should work most any system that supports ruby
for this to work you must also have https://github.com/franz-see/ccxt-rest#getting-started installed and running
