import fortfound_core/model.{
  type Card, type FullMove, type Game, type Location, type MoveRequest,
  type MoveToFoundation, type PartialMove, type State, type Suit,
  BlockingMinorArcanaFoundation, Clubs, Coins, Column, Cups, FullMove, Game,
  HistoryStep, MajorArcana, MajorArcanaFoundation, MinorArcana,
  MinorArcanaFoundation, MoveRequest, MoveToFoundation, PartialMove, State,
  Swords,
}
import fortfound_core/rng.{type Seed, shuffle}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/pair
import gleam/result
import gleam/set.{type Set}

fn generate_all_cards() -> List(Card) {
  let major_arcana =
    list.range(0, 21)
    |> list.map(MajorArcana)

  let minor_arcana = {
    use suit <- list.flat_map([Coins, Swords, Clubs, Cups])
    list.range(2, 13)
    |> list.map(MinorArcana(suit, _))
  }

  list.append(major_arcana, minor_arcana)
}

pub fn distribute_cards(cards: List(Card)) -> Dict(Int, List(Card)) {
  let columns = cards |> list.sized_chunk(7)

  let left_columns = columns |> list.take(5)
  let right_columns = columns |> list.drop(5)
  let all_columns = list.flatten([left_columns, [[]], right_columns])

  all_columns
  |> list.index_map(fn(column, index) { #(index, column) })
  |> dict.from_list
}

fn empty_state() -> State {
  State(
    major_arcana_foundation: MajorArcanaFoundation(low: None, high: None),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 1,
      swords: 1,
      clubs: 1,
      cups: 1,
      blocker: None,
    ),
    columns: list.range(0, 10) |> list.map(fn(i) { #(i, []) }) |> dict.from_list,
  )
}

pub fn empty_game() -> Game {
  Game(seed: None, state: empty_state(), history: [])
}

pub fn game_from_seed(seed: Seed) -> Game {
  let columns = generate_all_cards() |> shuffle(seed) |> distribute_cards()
  let state = State(..empty_state(), columns:)
  Game(seed: Some(seed), state:, history: [])
}

fn are_consecutive(n1: Int, n2: Int) -> Bool {
  int.absolute_value(n1 - n2) == 1
}

fn are_stackable(c1: Card, c2: Card) -> Bool {
  case c1, c2 {
    MajorArcana(v1), MajorArcana(v2) -> are_consecutive(v1, v2)
    MinorArcana(suit: s1, value: v1), MinorArcana(suit: s2, value: v2) ->
      s1 == s2 && are_consecutive(v1, v2)
    _, _ -> False
  }
}

fn get_column(state: State, index: Int) -> List(Card) {
  let assert Ok(column) = dict.get(state.columns, index)
  column
}

fn update_column(
  state: State,
  index: Int,
  fun: fn(List(Card)) -> List(Card),
) -> State {
  State(
    ..state,
    columns: dict.insert(
      into: state.columns,
      for: index,
      insert: state |> get_column(index) |> fun,
    ),
  )
}

pub fn get_card(state: State, loc: Location) -> Result(Card, Nil) {
  case loc {
    BlockingMinorArcanaFoundation ->
      state.minor_arcana_foundation.blocker
      |> option.to_result(Nil)

    Column(index) ->
      get_column(state, index)
      |> list.first
  }
}

fn remove_card(state: State, loc: Location) -> State {
  case loc {
    BlockingMinorArcanaFoundation -> state |> update_blocker(None)
    Column(index) -> state |> update_column(index, list.drop(_, 1))
  }
}

fn pop_card(state: State, loc: Location) -> Result(#(Card, State), Nil) {
  case get_card(state, loc) {
    Ok(card) -> Ok(#(card, remove_card(state, loc)))
    _ -> Error(Nil)
  }
}

fn update_blocker(state: State, card: Option(Card)) -> State {
  State(
    ..state,
    minor_arcana_foundation: MinorArcanaFoundation(
      ..state.minor_arcana_foundation,
      blocker: card,
    ),
  )
}

fn put_card_blocking_foundation(state: State, card: Card) -> Result(State, Nil) {
  case state.minor_arcana_foundation.blocker {
    None -> Ok(update_blocker(state, Some(card)))
    Some(_) -> Error(Nil)
  }
}

fn put_card_in_column(
  state: State,
  card: Card,
  index: Int,
) -> Result(State, Nil) {
  let valid = case get_column(state, index) {
    [] -> True
    [topmost, ..] -> are_stackable(card, topmost)
  }
  case valid {
    True -> Ok(state |> update_column(index, list.prepend(_, card)))
    False -> Error(Nil)
  }
}

fn put_card(state: State, card: Card, target: Location) -> Result(State, Nil) {
  case target {
    BlockingMinorArcanaFoundation -> put_card_blocking_foundation(state, card)
    Column(index) -> put_card_in_column(state, card, index)
  }
}

fn move_card(
  state: State,
  request: MoveRequest,
) -> Result(#(PartialMove, State), Nil) {
  use #(card, state) <- result.try(pop_card(state, request.source))
  use new_state <- result.try(put_card(state, card, request.target))
  Ok(#(PartialMove(request.source, card, request.target), new_state))
}

fn move_stack(
  state: State,
  request: MoveRequest,
) -> Result(#(PartialMove, List(PartialMove), State), Nil) {
  use #(first, state_after_first) <- result.try(move_card(state, request))

  let #(rest, new_state) = case move_stack(state_after_first, request) {
    Ok(#(second, others, new_state)) -> #([second, ..others], new_state)
    Error(_) -> #([], state_after_first)
  }

  Ok(#(first, rest, new_state))
}

fn validate_move(
  state: State,
  request: MoveRequest,
) -> Result(#(FullMove, State), Nil) {
  use <- bool.guard(request.source == request.target, return: Error(Nil))

  let move_result = move_stack(state, request)
  use #(requested, stacked, new_state) <- result.then(move_result)

  let #(to_foundations, new_state) = apply_colaterals(new_state)
  Ok(#(FullMove(requested:, stacked:, to_foundations:), new_state))
}

pub fn make_move(
  game: Game,
  request: MoveRequest,
) -> Result(#(FullMove, Game), Nil) {
  let move_result = validate_move(game.state, request)
  use #(move, new_state) <- result.then(move_result)
  let history = [HistoryStep(move.requested.card, game.state), ..game.history]
  let game = Game(..game, state: new_state, history:)
  Ok(#(move, game))
}

fn is_won(state: State) -> Bool {
  state.minor_arcana_foundation.coins == 13
  && state.minor_arcana_foundation.swords == 13
  && state.minor_arcana_foundation.clubs == 13
  && state.minor_arcana_foundation.cups == 13
  && case
    state.major_arcana_foundation.low,
    state.major_arcana_foundation.high
  {
    Some(low), Some(high) -> low + 1 == high
    _, _ -> False
  }
}

fn cartesian_product(l1: List(a), l2: List(a)) -> List(#(a, a)) {
  use first <- list.flat_map(l1)
  use second <- list.map(l2)
  #(first, second)
}

fn valid_moves(state: State) -> List(#(FullMove, State)) {
  let #(empty_columns, non_empty_columns) =
    state.columns
    |> dict.to_list
    |> list.partition(fn(key_val) { pair.second(key_val) |> list.is_empty })

  let sources = non_empty_columns |> list.map(pair.first) |> list.map(Column)
  let targets = case empty_columns {
    // This avoids listing multiple moves to different empty columns, which are effectively equivalent.
    [#(i, _), ..] -> [Column(i), ..sources]
    [] -> sources
  }

  // Minor arcana foundation is either a source or a target, depending on whether there is a card blocking it.
  let #(sources, targets) = case state.minor_arcana_foundation.blocker {
    Some(_) -> #([BlockingMinorArcanaFoundation, ..sources], targets)
    None -> #(sources, [BlockingMinorArcanaFoundation, ..targets])
  }

  cartesian_product(sources, targets)
  |> list.filter_map(fn(source_target) {
    let #(source, target) = source_target
    validate_move(state, MoveRequest(source, target))
  })
}

fn next_low_major_arcana(state: State) -> Int {
  state.major_arcana_foundation.low
  |> option.map(int.add(_, 1))
  |> option.unwrap(or: 0)
}

fn next_high_major_arcana(state: State) -> Int {
  state.major_arcana_foundation.high
  |> option.map(int.subtract(_, 1))
  |> option.unwrap(or: 21)
}

fn next_minor_arcana(state: State, suit: Suit) -> Int {
  case suit {
    Coins -> state.minor_arcana_foundation.coins + 1
    Swords -> state.minor_arcana_foundation.swords + 1
    Clubs -> state.minor_arcana_foundation.clubs + 1
    Cups -> state.minor_arcana_foundation.cups + 1
  }
}

fn is_ready_for_foundation(state: State, card: Card) -> Bool {
  case card, state.minor_arcana_foundation.blocker {
    MajorArcana(value), _ -> {
      let expected_low = next_low_major_arcana(state)
      let expected_high = next_high_major_arcana(state)
      value == expected_low || value == expected_high
    }
    MinorArcana(..), Some(_) -> False
    MinorArcana(suit, value), None -> value == next_minor_arcana(state, suit)
  }
}

pub fn find_ready_for_foundation(state: State) -> Result(Location, Nil) {
  let locations = [
    BlockingMinorArcanaFoundation,
    ..state.columns
    |> dict.keys()
    |> list.map(Column)
  ]

  list.find(locations, fn(loc) {
    case get_card(state, loc) {
      Ok(card) -> is_ready_for_foundation(state, card)
      _ -> False
    }
  })
}

fn move_to_foundation(state: State, card: Card) -> State {
  case card {
    MajorArcana(value) -> {
      let expected_low = next_low_major_arcana(state)
      let expected_high = next_high_major_arcana(state)

      let current = state.major_arcana_foundation
      let new = case value {
        _ if value == expected_low ->
          MajorArcanaFoundation(..current, low: Some(value))
        _ if value == expected_high ->
          MajorArcanaFoundation(..current, high: Some(value))
        _ -> panic
      }
      State(..state, major_arcana_foundation: new)
    }

    MinorArcana(suit, value) -> {
      let current = state.minor_arcana_foundation
      let new = case suit {
        Coins -> MinorArcanaFoundation(..current, coins: value)
        Swords -> MinorArcanaFoundation(..current, swords: value)
        Clubs -> MinorArcanaFoundation(..current, clubs: value)
        Cups -> MinorArcanaFoundation(..current, cups: value)
      }
      State(..state, minor_arcana_foundation: new)
    }
  }
}

fn apply_colaterals(state: State) -> #(List(MoveToFoundation), State) {
  case find_ready_for_foundation(state) {
    Ok(location) -> {
      let assert Ok(#(card, state_without_card)) = pop_card(state, location)
      let new_state = state_without_card |> move_to_foundation(card)
      let move = MoveToFoundation(location, card)
      let #(other_moves, new_state) = apply_colaterals(new_state)
      #([move, ..other_moves], new_state)
    }
    _ -> #([], state)
  }
}

fn count_consecutive_cards(column: List(Card)) -> Int {
  column
  |> list.window_by_2
  |> list.count(fn(cards) { are_stackable(cards.0, cards.1) })
}

fn score(state: State) -> Int {
  let empty_columns =
    state.columns
    |> dict.values
    |> list.count(list.is_empty)

  let major_arcanas_in_foundation =
    case state.major_arcana_foundation.low {
      Some(value) -> value + 1
      _ -> 0
    }
    + case state.major_arcana_foundation.high {
      Some(value) -> 21 - value + 1
      _ -> 0
    }

  let minor_arcanas_in_foundation =
    state.minor_arcana_foundation.coins
    + state.minor_arcana_foundation.swords
    + state.minor_arcana_foundation.clubs
    + state.minor_arcana_foundation.cups

  empty_columns
  * 100
  + major_arcanas_in_foundation
  * 10
  + minor_arcanas_in_foundation
  * 10
  + {
    state.columns
    |> dict.values
    |> list.map(count_consecutive_cards)
    |> int.sum
  }
}

pub fn is_winnable(state: State) -> Bool {
  is_winnable_aux([state], set.new())
}

fn merge_and_dedup(
  list1: List(a),
  list2: List(a),
  key: fn(a, a) -> Order,
) -> List(a) {
  case list1, list2 {
    [], _ -> list2
    _, [] -> list1
    [head1, ..tail1], [head2, ..tail2] ->
      case key(head1, head2) {
        order.Lt -> [head1, ..merge_and_dedup(tail1, list2, key)]
        order.Eq -> merge_and_dedup(tail1, list2, key)
        order.Gt -> [head2, ..merge_and_dedup(list1, tail2, key)]
      }
  }
}

fn compare_scores(s1: State, s2: State) -> Order {
  int.compare(score(s1), score(s2))
}

pub fn is_winnable_aux(pending: List(State), previous: Set(State)) -> Bool {
  case pending {
    [] -> False
    [state, ..rest_of_pending] ->
      case is_won(state) {
        True -> True
        False -> {
          let previous = previous |> set.insert(state)

          let next_states = valid_moves(state) |> list.map(pair.second)

          let pending =
            next_states
            |> list.filter(fn(state) { !set.contains(previous, state) })
            |> list.sort(by: compare_scores |> order.reverse)
            |> merge_and_dedup(rest_of_pending, compare_scores |> order.reverse)

          is_winnable_aux(pending, previous)
        }
      }
  }
}
