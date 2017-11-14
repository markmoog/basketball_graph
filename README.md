# basketball_graph
Create and analyze graphs of college basketball teams. Written in Nim.

This repository contains a module called basketball_graph which was designed for making and analyzing graphs of basketball teams primarily to determine relative team ability. It can be used for any sport, and possibly other things as well. The bbtool file along with some example data should demonstrate how to use the basketball_graph module.

# Using bbtool
bbtool can be compiled with the command line `nim c -d:ssl bbtool.nim`. After bbtool is compiled, it can be used with the example data and config file like so `./bbtool -a config_file` or `./bbtool -m config_file` Using the -m command outputs a matrix of relative 'distances' between teams. These distances can then be used to generate team ratings.
