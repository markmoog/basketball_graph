import httpclient
import strutils
import parsecsv
import streams
import utils
import neo
import times

type Game* = tuple[home_id: int, away_id: int, margin: int, is_neutral: bool, date: Date]
type Edge* = tuple[node: int, weight: float]
type Graph* = seq[seq[Edge]]


# Parses a game records file (format spec below) and output a graph of the games
# Input File Format
# Game date: characters 0 to 10
# Home team name: characters 11 to 33
# ... look at the function for the rest of the expected format
# The neutral_overtime entry should contain an N if the game is neutral, n if it
#   is semi-neutral and the number of overtimes if the game went to overtime.
#   For example: N means the game was on a neutral court, 3 would mean the game
#   had 3 overtimes, and N3 means the game was neutral and had 3 overtimes.

proc load_games*(url: string, teams: seq[string]): seq[Game] =
  let start_time = cpu_time()

  var game_data: string
  var games = new_seq[Game](0)

  # Check to see if we load from either a website or a local file
  if url[0..4] == "http":
    let client = new_http_client()
    game_data = client.get_content(url)
  else:
    game_data = new_file_stream(url, fm_read).read_all()

  # Loop through all games and fill temporary matrices
  for line in split_lines(game_data):
    if line.len() > 0:
      let date: Date = line[0..10].strip().parse_date()
      let home_team: string = line[11 .. 33].strip()
      let home_score: int = line[34 .. 37].strip().parse_int()
      let away_team: string = line[38 .. 60].strip()
      let away_score: int = line[61 .. 64].strip().parse_int()
      let neutral_overtime: string = line[65..68]

      # Convert home_team and away_team from names to ids
      let home_id = teams.index_of(home_team)
      let away_id = teams.index_of(away_team)

      # extract neutrality
      let is_neutral = (neutral_overtime[0] == 'N')

      let margin = home_score - away_score
      let game: Game = (home_id, away_id, margin, is_neutral, date)

      # Make sure both teams are present in the 'teams' argument to this
      # funciton, then add their data to the intermediate matrices
      if game.home_id != -1 and game.away_id != -1:
        games.add(game)

  echo("Game loading time: " & format_float(cpu_time() - start_time))
  return games


# Selects games which occured in the specified range of dates from all the
# games in a sequence.

proc in_range*(games: seq[Game], start_date: Date, end_date: Date): seq[Game] =
  var selection = new_seq[Game]()

  for game in games:
    if game.date >= start_date and game.date <= end_date:
      selection.add(game)

  return selection


# Loads an array of comma seperated team names from a file.
# Only games where both teams are present in this file will be used to build the
# graph. This can be used to exclude games against certain teams from the
# overall analysis such as games against non-D1 teams that may be present in
# game records file.

proc load_teams*(file_path: string): seq[string] =
  let start_time = cpu_time()

  let team_stream = new_file_stream(file_path, fm_read)
  if team_stream == nil:
    quit("Cannot open the file.")

  var parser: CSV_Parser
  open(parser, team_stream, file_path)

  var teams = new_seq[string](0)
  while read_row(parser):
    for t in parser.row:
      if not is_nil_or_whitespace(t):
        teams.add(t)

  echo("Team load time: " & format_float(cpu_time() - start_time))
  return teams


# Takes a file location (either a URL or a local file path), as well as a list
# of the team names (which need to be identical to the names of interest in the
# game records file) and creates a graph of the games.

proc build_graph*(games: seq[Game], teams: seq[string]): Graph =
  let start_time = cpu_time()

  let size = len(teams)

  # Create intermediate matrices that will be used to build the graph. These are
  # needed so teams that play each other multiple times during the season do not
  # have multiple edges between them in the graph. They will have one edge with
  # a weight that is the average of the score differential of all the games.
  var distance_matrix = zeros(size, size)
  var path_count_matrix = zeros(size, size)

  for game in games:
    distance_matrix[game.home_id, game.away_id] = distance_matrix[game.home_id, game.away_id] + float(game.margin)
    path_count_matrix[game.home_id, game.away_id] = path_count_matrix[game.home_id, game.away_id] + 1

    distance_matrix[game.away_id, game.home_id] = distance_matrix[game.away_id, game.home_id] - float(game.margin)
    path_count_matrix[game.away_id, game.home_id] = path_count_matrix[game.away_id, game.home_id] + 1

  # If teams played multiple times we average their score differential so there
  # is at most one edge between teams.
  for r in countup(0, <size):
     for c in countup(0, <size):
       if path_count_matrix[r, c] != 0:
         distance_matrix[r, c] = distance_matrix[r, c] / path_count_matrix[r, c]

  # Build a graph from the intermediate matrices
  var graph: Graph = new_seq[seq[Edge]](size)

  for home_node in countup(0, <size):
    for away_node in countup(0, <size):
      if path_count_matrix[home_node, away_node] != 0:
        let edge: Edge = (away_node, distance_matrix[home_node, away_node])
        if graph[home_node] == nil:
          graph[home_node] = @[edge]
        else:
          graph[home_node].add(edge)

  echo("Graph building time: " & format_float(cpu_time() - start_time))
  return graph


proc build_graph*(games_url: string, teams_url: string): Graph =
  let teams = load_teams(teams_url)
  let games = load_games(games_url, teams)

  return build_graph(games, teams)


# Takes a path length and graph of teams as input and outputs a matrix of the
# average distances between each pair of teams. Distance between teams are
# calculated by traversing all paths of a given length connecting each pair
# of teams in the graph and computing the average distance between them.

proc build_distance_matrix*(graph: Graph, max_depth: int): Matrix[float64] =
  let start_time = cpu_time()
  let size: int = len(graph)

  var distance_matrix: Matrix[float64] = zeros(size, size)
  var path_count_matrix: Matrix[float64] = zeros(size, size)

  proc traverse_graph(graph: Graph, current_node: int, cumulative_distance: float, depth: int, visited_nodes: seq, max_depth: int): void =
    let depth = depth + 1
    let visited_nodes = visited_nodes & current_node

    for child_node in graph[current_node]:
      if visited_nodes.index_of(child_node.node) == -1:
        let cumulative_distance = cumulative_distance + child_node.weight

        if depth == max_depth:
            # visited_nodes[0] is the root node
            distance_matrix[visited_nodes[0], child_node.node] = distance_matrix[visited_nodes[0], child_node.node] + cumulative_distance
            path_count_matrix[visited_nodes[0], child_node.node] = path_count_matrix[visited_nodes[0], child_node.node] + 1
        else:
          traverse_graph(graph, child_node.node, cumulative_distance, depth, visited_nodes, max_depth)

  # Loop through every team, this will double-count all paths but oh well. We
  # will fill in each half of the matrix seperately even though it is
  # antisymmetric.
  for i in countup(0, <size):
    # Find all paths of length max_depth that start (or end depending on how you
    # look at it) at node i, add path distances to distance matrix.
    traverse_graph(graph, i, 0.0, 0, new_seq[int](0), max_depth)

  # Calculate averages
  for r in countup(0, <size):
    for c in countup(0, <r):
      if path_count_matrix[r, c] != 0:
        let d = distance_matrix[r, c] / path_count_matrix[r, c]
        distance_matrix[r, c] = d
        distance_matrix[c, r] = -d

  echo("Distance matrix build time: " & format_float(cpu_time() - start_time))
  return distance_matrix


# Determines the shortest path length s for the graph such that every pair of
# nodes in the graph can be connected by a path of length s. Will not check for
# path lengths greater than the depth limit.

proc shortest_spanning_path*(graph: Graph, depth_limit: int): int =
  let start_time = cpu_time()
  let size: int = len(graph)

  var max_depth: int = 1
  while max_depth <= depth_limit:
    var connection_matrix: Matrix[float64] = zeros(size, size)

    proc traverse_graph(graph: Graph, current_node: int, cumulative_distance: float, depth: int, visited_nodes: seq, max_depth: int): void =
      let depth = depth + 1
      let visited_nodes = visited_nodes & current_node

      for child_node in graph[current_node]:
        if visited_nodes.index_of(child_node.node) == -1:
          connection_matrix[visited_nodes[0], child_node.node] = 1

          if depth == max_depth:
              break
          else:
            traverse_graph(graph, child_node.node, cumulative_distance, depth, visited_nodes, max_depth)

    for i in countup(0, <size):
      traverse_graph(graph, i, 0.0, 0, new_seq[int](0), max_depth)

    var fully_connected: bool = true

    # Check to see if the connection_matrix has paths connecting every pair of nodes
    for r in countup(0, <size):
      for c in countup(0, <r):
        if connection_matrix[r, c] == 0:
          fully_connected = false
          break

    if fully_connected:
      echo("Shortest spanning path time: " & format_float(cpu_time() - start_time))
      return max_depth

    # the graph is not spanned by the current path length, try the next path length
    inc max_depth

  echo("Shortest spanning path time (hit depth limit): " & format_float(cpu_time() - start_time))
  return -1


# Takes a graph of games, two teams, and a path length, and returns an array
# containing the cumulative distances of each path between the teams with the
# specified path length.

proc build_distance_array*(graph: Graph, source_node: int, sink_node: int, max_depth: int): seq[float] =
  let start_time = cpu_time()

  if source_node == -1 or sink_node == -1:
    quit("Source or sink team is not listed in teams file.")

  var distances = new_seq[float](0)

  proc traverse_graph(graph: Graph, max_depth: int, sink_node: int, current_node: int, cumulative_distance: float, depth: int, visited_nodes: seq): void =
    let depth = depth + 1
    let visited_nodes = visited_nodes & current_node

    for child_node in graph[current_node]:
      # Make sure we haven't already visited this node
      if visited_nodes.index_of(child_node.node) == -1:
        let cumulative_distance = cumulative_distance + child_node.weight

        if depth == max_depth:
          if child_node.node == sink_node:
            distances.add(cumulative_distance)
        elif child_node.node != sink_node:
          traverse_graph(graph, max_depth , sink_node, child_node.node, cumulative_distance, depth, visited_nodes)

  traverse_graph(graph, max_depth, sink_node, source_node, 0.0, 0, new_seq[int](0))

  echo("Distance array build time: " & format_float(cpu_time() - start_time))
  return distances
