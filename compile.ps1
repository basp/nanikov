ls ./src/*.erl | foreach { erlc -o ./ebin $_.FullName }