{application, nanikov,
 [{description, "A random text generator."},
  {vsn, "0.1.0"},
  {modules, [markov_app, markov_sup]},
  {registered, []},
  {applications, [kernel, stdlib, sasl]},
  {mod, {markov_app, []}}
]}.