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

# notes on the random text generation
This is just for those who are interested or wanna make sense
of the stuff in `markov.erl` (this includes me in a few months).

## it all starts with ngrams
The algorithm works with lists (or sequences) of tokens. What your
token is doesn't really matter. In this case we use strings. It
starts by converting tokens into so called *ngrams*. An `ngram`
is basically a tuple of tokens that appeared in that order in some
source of tokens.

The goal is to create something that can give us a random sequence
of tokens of a particular length in which the order of the tokens
is based on the likeleyhood they where found in some kind of 
source material (e.g. existing tokens).

Let's consider this sentence. In tokens it would like:
```
Tokens = ["let's", "consider", "this", "sentence"].
```

We normalized whitespace, capitalization and most of 
the punctuation. Depending on your scenario, it's often a good
idea to sanitize your source somewhat before you use it to feed 
your markov generator.

Once we have a list of tokens (whatever they might be) we can use
this to create ngrams. Let's start with *bigrams* (ngrams of rank 2, 
e.g. normal tuples):
```
Bigrams = [
    {"let's", "consider"}, 
    {"consider", "this"}, 
    {"this", "sentence"}].
```

This is what `markov:bigrams/1` does. This is just a helper that
calls the more generic `markov:ngrams/2` function which can be used
to create ngrams up to rank 5.

Now we have the start of something interesting but we're not there
yet. Next we need to use these bigrams in order to create a tuple
consisting of the bigram and a list of words that are likely to
follow it.

So what the algorithm does next is basically scan through the ngrams
and depending on whether it's a new `ngram()` or a known one, either
remember `{ngram(), [token()]}` or retrieve it, append `token()` to the list 
of known tokens and store it again.

In other words, what you're creating is a map from `ngram()` to `[token()]`.
Let's call this *map* (or dictionary) `memory`.

This implementation is not efficient on memory as we are storing
tokens more than one time. This conveniently allows us to pick any random
one without any work. 

We could (for example) make it more efficient to pack up *L* into
a list `[{integer(), token()}]` tuples so that we can still perform a 
(random) lookup based on chance as well as store them in a more efficient 
manner.  

For now I kinda like the simplicity of the algorithm and to be honest,
the `memory` is not meant to grow *that* big at this point in development
so I don't wanna overload the bot with stuff that might be better implemented
when the design is more stable.

Concluding, even when seeding the bot with a substantial amount of text
the actual memory required by the `memory` ETS tables is quite low. At least
compared to everything else you're running.

## generation of (random) tokens

Once you have such a map you're able to generate random stuff that's famous
for being utterly nonsense most of the time (even though it seems to make 
sense at a glimpse) and hauntingly insightful and other times (when the stars 
align).

0. Our initial state is an empty list `[token()]` *S* and the `memory` dictionary
as described above. Additionaly we picked a key *K* from the known keys in `memory`.  
1. We get the value associated with *K* (which is, a `ngram()` tuple) from `memory`. 
This will give us a `{ngram(), Q = [token()]}`. That is, the key we looked for and 
a list of tokens.
2. We'll pick some `token()` from the list of tokens `[token()]` (*Q*).
3. We'll append this `token()` *T* to *S* (the list of selected tokens `[token()]`.
4. Now we need to combine *K* with *T* in some way that it produces a new key *K2*;
how to do this depends on the rank of ngram(s) your dealing with. For illustration
We'll focus on the bigram case. This assumes that *K* is a tuple `{token(), token()}`.
5. We combine *K* `{A, B}` with *T* so that we have a new tuple *K2* `{B, T}`. 
6. Repeat from step 1 substituting *K* with our new *K2* until we are satisfied with
the length of *S*.

Now we'll end up with a bunch of random tokens in *S* which we basically can just return, 
join and use as some jibberish. 

Below is the code in *pseudo* Erlang corresponding to the steps mentioned above:
```
S = [].                                 % 1
K = {A, B} = memory:get_random_key().   % 1, `bigram' case
{K, Q} = memory:get(K).                 % 2
T = utils:random_element(Q).            % 3
S2 = [T | S].                           % 4/5
K2 = {B, T}.                            % 5/6

% Functionally, we would recurse with `K2` and accumulator `S2`.
% Imperatively we can say that `K <- K2` and `S <- S2`.
```

## how it's stored internally
We're using a very simple setup of a table consisting tuples of tokes (ngrams) and a list
of tokens (candidates). It's a map of *K* `ngram()` to *V* `[token()]` where:

```
token() :: term(). % basically anything your language can support

ngram() :: {token(), token()}
         | ...  
         | {token(), token(), token(), token(), token()}. % ngrams!

% a key (ngram) and a list of candidate following tokens
entry() :: {ngram, [token()]}.

```

You can deal with ngrams of a particalar rank only or mix and match if you want. Although
you will have to extend the algorithm which only is supported to deal with ngrams
of a uniform rank (and only bigrams too currently).

The `{Key :: ngram(), Value :: [token()]` values are basically stored as is. The key is
the `ngram()` and the value is the candidate list `[token()]`. However, we wanna lookup
random keys efficiently and **scanning** the table is **undesirable** so we'll use an 
additional index table. This is just an `index() :: integer()` key and an `ngram()` value:
`{index :: integer(), ngram()}`.  

Now we just keep track of the number of keys in our runtime state (we need that anyway 
to generate new index numbers) and basicallly use that as our upper limit whenever we 
need to generate a new random key. Then we'll update the ngrams table and the index
table as necessary. Depending on whether we found an exisitng ngram or a new one when
updating the `memory`. 

Now we can just roll any kind of number between `StartIndex` and `NextIndex` and we
fetch any key from `memory` at *O(1)* speed. No scanning.

## about `memory`
If we have been a bit opaque about how memory itself is implemented that is
because it doesn't really matter. In fact, it might even be better of as pair of 
functions. Below is the required interface for any `memory` substitute.
```
remember(Key :: ngram(), Candidate :: token()) -> ignored.
retrieve(Key :: ngram()) -> Candidates :: [token()]. 
```