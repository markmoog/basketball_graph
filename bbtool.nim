import basketball_graph
import os
import streams
import strutils
import neo
import system

proc write_distance_matrix(config_path: string): void =
  var
    games_path: string
    teams_path: string
    output_path: string
    max_depth: int

  let config_data = new_file_stream(config_path, fm_read).readAll()
  if config_data == nil:
    quit("Cannot open configuration file")

  # Read the config file
  for line in split_lines(config_data):
    let key_value= split(line, ':')
    if key_value.len != 2:
      continue
    let key: string = key_value[0]
    let value: string = key_value[1]

    case key:
      of "Games File":
        games_path = value.strip()
      of "Teams File":
        teams_path = value.strip()
      of "Output File":
        output_path = value.strip()
      of "Maximum Depth":
        max_depth = value.strip().parse_int()
      else:
        echo("Unrecognised entry in config")

  # Make sure all required fields have been read
  if games_path == nil or teams_path == nil or output_path == nil or max_depth == 0:
    quit("Configuration parameters either not present or unallowed")

  echo("Constructing matrix with maximum depth " & int_to_str(max_depth))
  let d_mat = build_distance_matrix(games_path, teams_path, max_depth)

  echo("Writing data to file")
  var file_stream = new_file_stream(output_path, fmWrite)

  for row in d_mat.rows:
    for col, item in row:
      file_stream.write(format_float(item))
      if col < 351:
        file_stream.write(",")
    file_stream.write("\n")


proc write_distance_array(config_path: string): void =
  var
    games_path: string
    teams_path: string
    output_path: string
    source_name: string
    sink_name: string
    max_depth: int

  let config_data = new_file_stream(config_path, fm_read).readAll()
  if config_data == nil:
    quit("Cannot open configuration file")

  # Read the config file
  for line in split_lines(config_data):
    let key_value= split(line, ':')
    if key_value.len != 2:
      continue
    let key: string = key_value[0]
    let value: string = key_value[1]

    case key:
      of "Games File":
        games_path = value.strip()
      of "Teams File":
        teams_path = value.strip()
      of "Source Team":
        source_name = value.strip()
      of "Sink Team":
        sink_name = value.strip()
      of "Output File":
        output_path = value.strip()
      of "Maximum Depth":
        max_depth = value.strip().parse_int()
      else:
        echo("Unrecognised entry in config")

  # Make sure all required fields have been read
  if games_path == nil or teams_path == nil or output_path == nil or source_name == nil or sink_name == nil or max_depth == 0:
    quit("Configuration parameters either not present or unallowed")

  echo("Constructing matrix with maximum depth " & int_to_str(max_depth))
  let d_array = build_distance_array(games_path, teams_path, source_name, sink_name, max_depth)

  echo("Writing data to file")
  var file_stream = new_file_stream(output_path, fmWrite)

  for d in d_array:
    file_stream.write(format_float(d) & ",\n")


# Check the parameter string to determine what to do
let function = param_str(1)
let config_path = param_str(2)

case function:
  of "-m":
    echo("Distance matrix")
    write_distance_matrix(config_path)

  of "-a":
    echo("Distance array")
    write_distance_array(config_path)

  else:
    echo("Bad parameters")

