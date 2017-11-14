import neo
import basketball_graph
import os
import strutils
import streams
import utils
import tables


# Parameters should be contained in a config file, who's path is passed from the
# command line. The following parameters are expected:
# games path: ... the path to the file containing game data
# teams path: ... the path to the file containing team names
# output path: ... the path to the file where output is saved
# max depth: ... the traversal depth of the graph used to generate output
# sink name: ... only for generating distance arrays, name of the sink team
# source name: ... only for generating distance arrays, name of the source team


proc write_distance_matrix(config: Table_Ref): void =
  echo("Constructing matrix with maximum depth " & config["max depth"])

  let graph = build_graph(config["games path"], config["teams path"])
  let max_depth: int = parse_int(config["max depth"])
  let d_mat = build_distance_matrix(graph, max_depth)

  echo("Writing data to file")
  var file_stream = new_file_stream(config["output path"], fmWrite)

  for row in d_mat.rows:
    for col, item in row:
      file_stream.write(format_float(item))
      if col < <row.len:
        file_stream.write(",")
    file_stream.write("\n")


proc write_distance_array(config: Table_Ref): void =
  echo("Constructing array with maximum depth " & config["max depth"])

  let teams = load_teams(config["teams path"])
  let graph = build_graph(config["games path"], config["teams path"])

  let source_id = teams.index_of(config["source name"])
  let sink_id = teams.index_of(config["sink name"])
  let max_depth = parse_int(config["max depth"])

  let d_array = build_distance_array(graph, source_id, sink_id, max_depth)

  echo("Writing data to file")
  var file_stream = new_file_stream(config["output path"], fmWrite)

  for d in d_array:
    file_stream.write(format_float(d) & ",\n")


# Check the command line arguments string to determine what to do.
# The first argument determines whether to generate an array of distances
# between two teams (-a), or generate a matrix of average distances between all
# teams (-m). The second argument is the path to a config file which determines
# the parameters used to generate output.
let function = param_str(1)
let config_path = param_str(2)
let config = load_config(config_path)

case function:
  of "-m":
    echo("Distance matrix")
    write_distance_matrix(config)

  of "-a":
    echo("Distance array")
    write_distance_array(config)

  else:
    echo("Bad command line arguments")

