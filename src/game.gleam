import engine
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import kitten/math
import kitten/vec2.{Vec2}
import model.{
  type Card, type Game, type Location, type MajorArcanaFoundation,
  type MinorArcanaFoundation, type Move, type State, type Suit,
  BlockingMinorArcanaFoundation, Clubs, Coins, Column, Cups, Game, MajorArcana,
  MajorArcanaFoundation, MinorArcana, MinorArcanaFoundation, Move, State, Swords,
  UndoButton,
}
import styles

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

fn distribute_cards(cards: List(Card)) -> Dict(Int, List(Card)) {
  let columns = cards |> list.shuffle |> list.sized_chunk(7)

  let left_columns = columns |> list.take(5)
  let right_columns = columns |> list.drop(5)
  let all_columns = list.append(left_columns, [[], ..right_columns])

  all_columns
  |> list.index_map(fn(column, index) { #(index, column) })
  |> dict.from_list
}

pub fn init() -> Game {
  let current_state =
    State(
      major_arcana_foundation: MajorArcanaFoundation(low: None, high: None),
      minor_arcana_foundation: MinorArcanaFoundation(
        coins: 1,
        swords: 1,
        clubs: 1,
        cups: 1,
        blocking: None,
      ),
      columns: generate_all_cards() |> distribute_cards(),
    )

  // Do not accept initial state where some cards can immediately go to foundations.
  case find_ready_for_foundation(current_state) {
    Ok(_) -> init()
    Error(_) -> Game(current_state:, moved_card: None, previous_state: None)
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
  use card <- result.map(get_card(state, loc))
  let new_state = remove_card(state, loc)
  #(card, new_state)
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
  use <- bool.guard(move.source == move.target, False)

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
  case card {
    MajorArcana(value) -> {
      let expected_low = next_low_major_arcana(state)
      let expected_high = next_high_major_arcana(state)
      value == expected_low || value == expected_high
    }
    MinorArcana(suit, value) -> value == next_minor_arcana(state, suit)
  }
}

fn find_ready_for_foundation(state: State) -> Result(Location, Nil) {
  let locations = [
    BlockingMinorArcanaFoundation,
    ..state.columns
    |> dict.keys()
    |> list.map(Column)
  ]

  let minor_arcana_blocked =
    state.minor_arcana_foundation.blocking |> option.is_some()

  list.find_map(locations, fn(loc) {
    use card <- result.try(get_card(state, loc))
    case card, minor_arcana_blocked {
      MinorArcana(_, _), True -> Error(Nil)
      _, _ ->
        case is_ready_for_foundation(state, card) {
          True -> Ok(loc)
          False -> Error(Nil)
        }
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

fn try_make_move(state: State, move: Move) -> #(State, Option(Card)) {
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

pub fn update(game: Game, event: engine.Event(Location)) -> Game {
  case event {
    engine.Clicked(UndoButton) -> {
      case game.previous_state {
        None -> game
        Some(previous_state) ->
          Game(..game, current_state: previous_state, moved_card: None)
      }
    }

    // TODO: allow click to select.
    engine.Clicked(_) -> game

    engine.Released(source, target) -> {
      let #(state_after_move, moved_card) =
        game.current_state |> try_make_move(Move(source, target))
      let previous_state = Some(game.current_state)

      case state_after_move == game.current_state {
        True -> game
        False ->
          Game(current_state: state_after_move, moved_card:, previous_state:)
      }
    }
  }
}

fn view_slot(column_index: Int, targettable: Bool) -> engine.Object(Location) {
  engine.Object(
    name: "slot " <> int.to_string(column_index),
    loc: Some(Column(column_index)),
    position: styles.tableau_card_position(column_index:, card_index: 0),
    size: styles.card_size,
    draw: fn(obj, context) { styles.draw_slot(obj.position, context) },
    clickable: False,
    draggable: False,
    targettable:,
  )
}

fn card_name(card: Card) -> String {
  case card {
    MajorArcana(value) -> "major " <> int.to_string(value)
    MinorArcana(Clubs, value) -> "clubs " <> int.to_string(value)
    MinorArcana(Coins, value) -> "coins " <> int.to_string(value)
    MinorArcana(Cups, value) -> "cups " <> int.to_string(value)
    MinorArcana(Swords, value) -> "swords " <> int.to_string(value)
  }
}

fn view_cards(
  column_index: Int,
  cards: List(Card),
) -> List(engine.Object(Location)) {
  // Topmost card last.
  let last_card_index = list.length(cards) - 1
  let cards = list.reverse(cards)
  use card, card_index <- list.index_map(cards)

  engine.Object(
    name: card_name(card),
    loc: Some(Column(column_index)),
    position: styles.tableau_card_position(column_index:, card_index:),
    size: styles.card_size,
    draw: fn(obj, context) { styles.draw_card(card, obj.position, context) },
    clickable: card_index == last_card_index,
    draggable: card_index == last_card_index,
    targettable: card_index == last_card_index,
  )
}

fn view_column(column: #(Int, List(Card))) -> List(engine.Object(Location)) {
  let #(column_index, cards) = column

  case cards {
    [] -> [view_slot(column_index, True)]
    _ ->
      [view_slot(column_index, False), ..view_cards(column_index, cards)]
      |> list.reverse()
  }
}

fn view_major_arcana_foundation(
  foundation: MajorArcanaFoundation,
) -> engine.Object(Location) {
  engine.Object(
    name: "major arcana foundation",
    loc: None,
    position: styles.major_arcana_foundation_position(),
    size: styles.card_size,
    draw: fn(obj, context) {
      styles.draw_major_arcana_foundation(foundation, obj.position, context)
    },
    clickable: False,
    draggable: False,
    targettable: False,
  )
}

fn view_minor_arcana_foundation(
  foundation: MinorArcanaFoundation,
) -> List(engine.Object(Location)) {
  let position = styles.minor_arcana_foundation_position()

  let foundation_cards =
    engine.Object(
      name: "minor arcana foundation",
      loc: Some(BlockingMinorArcanaFoundation),
      position:,
      size: styles.minor_arcana_foundation_size(),
      draw: fn(obj, context) {
        styles.draw_minor_arcana_foundation(foundation, obj.position, context)
      },
      clickable: False,
      draggable: False,
      targettable: foundation.blocking |> option.is_none,
    )

  let blocking_card = {
    use card <- option.map(foundation.blocking)
    let angle = math.deg_to_rad(-90.0)
    engine.Object(
      name: "blocking: " <> card_name(card),
      loc: Some(BlockingMinorArcanaFoundation),
      position:,
      size: Vec2(x: styles.card_size.y, y: styles.card_size.x),
      draw: fn(obj, context) {
        styles.draw_rotated_card(card, obj.position, angle, context)
      },
      clickable: False,
      draggable: True,
      targettable: False,
    )
  }

  case blocking_card {
    Some(blocking_card) -> [blocking_card, foundation_cards]
    None -> [foundation_cards]
  }
}

fn view_undo_button(moved_card: Card) -> engine.Object(Location) {
  engine.Object(
    name: "undo: " <> card_name(moved_card),
    loc: Some(UndoButton),
    position: styles.undo_button_position(),
    size: styles.undo_button_size(),
    draw: fn(obj, context) {
      styles.draw_undo_button(moved_card, obj.position, context)
    },
    clickable: True,
    draggable: False,
    targettable: False,
  )
}

pub fn view(game: Game) -> List(engine.Object(Location)) {
  let state = game.current_state

  state.columns
  |> dict.to_list
  |> list.flat_map(view_column)
  |> list.append([
    view_major_arcana_foundation(state.major_arcana_foundation),
    ..view_minor_arcana_foundation(state.minor_arcana_foundation)
  ])
  |> list.append(case game.moved_card {
    Some(moved_card) -> [view_undo_button(moved_card)]
    None -> []
  })
}
