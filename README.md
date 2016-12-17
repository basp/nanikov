# nanikov
This is the random text generator part that used to be part of the nanibot 
project.

# setup
First compile the source:

    .\compile.ps1

Then you can bootup an Erlang shell and go the ebin directory:

    cd("/nanikov/ebin").

And startup the application:

    application:start(nanikov).

Or just use your preferred way to statup an OTP application.

# usage
Before we can generate text we have to seed the generator first:

    markov_server:seed("foo bar quux").

And then generate (up to) a number of gibberish:

    markov_server:generate(13).