import fortfound_core/rng.{type Seed, random_seed, shuffle}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/pair
import gleam/set.{type Set}

import fortfound_core/model.{
  type Card, type Game, type Location, type MajorArcanaFoundation,
  type MinorArcanaFoundation, type Move, type State, type Suit,
  BlockingMinorArcanaFoundation, Clubs, Coins, Column, Cups, Game, MajorArcana,
  MajorArcanaFoundation, MinorArcana, MinorArcanaFoundation, Move, State, Swords,
}

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

pub fn empty_state() -> State {
  State(
    major_arcana_foundation: MajorArcanaFoundation(low: None, high: None),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 1,
      swords: 1,
      clubs: 1,
      cups: 1,
      blocking: None,
    ),
    columns: dict.new(),
  )
}

pub fn game_from_seed(seed: Seed) -> Game {
  let columns = generate_all_cards() |> shuffle(seed) |> distribute_cards()
  let current_state = State(..empty_state(), columns:)
  Game(seed:, current_state:, moved_card: None, previous_state: None)
}

pub fn random_game() -> Game {
  let game = game_from_seed(random_seed())
  // Do not accept initial state where some cards can immediately go to foundations.
  case find_ready_for_foundation(game.current_state) {
    Ok(_) -> random_game()
    _ -> game
  }
}

pub fn random_winnable_game() -> Game {
  let game = random_game()
  case is_winnable(game.current_state) {
    True -> game
    False -> random_winnable_game()
  }
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

fn get_card(state: State, loc: Location) -> Result(Card, Nil) {
  case loc {
    BlockingMinorArcanaFoundation ->
      state.minor_arcana_foundation.blocking
      |> option.to_result(Nil)

    Column(index) ->
      get_column(state, index)
      |> list.first

    _ -> panic
  }
}

fn update_blocker(state: State, card: Option(Card)) -> State {
  State(
    ..state,
    minor_arcana_foundation: MinorArcanaFoundation(
      ..state.minor_arcana_foundation,
      blocking: card,
    ),
  )
}

fn update_column(
  state: State,
  at index: Int,
  with func: fn(List(Card)) -> List(Card),
) -> State {
  State(
    ..state,
    columns: dict.insert(
      into: state.columns,
      for: index,
      insert: get_column(state, index) |> func,
    ),
  )
}

fn remove_card(state: State, loc: Location) -> State {
  case loc {
    BlockingMinorArcanaFoundation -> state |> update_blocker(None)
    Column(index) -> state |> update_column(at: index, with: list.drop(_, 1))
    _ -> panic
  }
}

fn pop_card(state: State, loc: Location) -> Result(#(Card, State), Nil) {
  case get_card(state, loc) {
    Ok(card) -> Ok(#(card, remove_card(state, loc)))
    _ -> Error(Nil)
  }
}

fn put_card(state: State, card: Card, in loc: Location) -> State {
  case loc {
    BlockingMinorArcanaFoundation -> state |> update_blocker(Some(card))
    Column(index) ->
      state |> update_column(at: index, with: list.prepend(_, card))
    _ -> panic
  }
}

fn is_valid(state: State, move: Move) -> Bool {
  let selected = get_card(state, move.source)
  case selected, move.target {
    Error(Nil), _ -> False

    _, BlockingMinorArcanaFoundation ->
      state.minor_arcana_foundation.blocking |> option.is_none

    Ok(card), Column(index) -> {
      case get_column(state, index) {
        [] -> True
        [topmost, ..] -> are_stackable(card, topmost)
      }
    }

    _, _ -> panic
  }
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
  case card, state.minor_arcana_foundation.blocking {
    MajorArcana(value), _ -> {
      let expected_low = next_low_major_arcana(state)
      let expected_high = next_high_major_arcana(state)
      value == expected_low || value == expected_high
    }
    MinorArcana(..), Some(_) -> False
    MinorArcana(suit, value), None -> value == next_minor_arcana(state, suit)
  }
}

fn find_ready_for_foundation(state: State) -> Result(Location, Nil) {
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

fn apply_colaterals(state: State) -> State {
  case find_ready_for_foundation(state) {
    Ok(location) -> {
      let assert Ok(#(card, state_without_card)) = pop_card(state, location)
      let new_state = state_without_card |> move_to_foundation(card)
      apply_colaterals(new_state)
    }
    _ -> state
  }
}

pub fn try_make_move(state: State, move: Move) -> #(State, Option(Card)) {
  case is_valid(state, move) {
    True -> {
      let assert Ok(#(selected, state)) = pop_card(state, move.source)

      let #(new_state, _) =
        state
        |> put_card(selected, in: move.target)
        // Repeat to move whole stacks.
        |> try_make_move(move)

      #(new_state, Some(selected))
    }
    False -> #(apply_colaterals(state), None)
  }
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

fn valid_moves(state: State) -> List(Move) {
  let #(empty_columns, non_empty_columns) =
    state.columns
    |> dict.to_list
    |> list.partition(fn(index_and_column) { list.is_empty(index_and_column.1) })
    |> pair.map_first(list.map(_, pair.first))
    |> pair.map_second(list.map(_, pair.first))

  let potential_sources = non_empty_columns |> list.map(Column)

  let potential_targets = case empty_columns {
    [empty_column, ..] -> [Column(empty_column), ..potential_sources]
    _ -> potential_sources
  }

  let #(potential_sources, potential_targets) = case
    state.minor_arcana_foundation.blocking
  {
    Some(_) -> #(
      [BlockingMinorArcanaFoundation, ..potential_sources],
      potential_targets,
    )
    None -> #(potential_sources, [
      BlockingMinorArcanaFoundation,
      ..potential_targets
    ])
  }

  potential_sources
  |> list.flat_map(fn(source) {
    potential_targets
    |> list.map(fn(target) { Move(source, target) })
  })
  |> list.filter(is_valid(state, _))
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

          let next_states =
            valid_moves(state)
            |> list.map(fn(move) {
              let #(state, _) = try_make_move(state, move)
              state
            })

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
