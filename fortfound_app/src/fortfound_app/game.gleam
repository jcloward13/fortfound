import fortfound_app/engine
import fortfound_app/styles
import fortfound_core/game.{game_from_seed, try_make_move}
import fortfound_core/model.{
  type Card, type Game, type Location, type MajorArcanaFoundation,
  type MinorArcanaFoundation, type Move, BlockingMinorArcanaFoundation, Clubs,
  Coins, Column, Cups, Game, MajorArcana, MajorArcanaFoundation, MinorArcana,
  MinorArcanaFoundation, Move, Swords, UndoButton,
}
import fortfound_core/rng
import fortfound_core/scenarios
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/uri
import kitten/vec2.{Vec2}
import plinth/browser/window

fn get_seed() -> Result(rng.Seed, Nil) {
  let assert Ok(url) = uri.parse(window.location())

  use query <- result.try(
    url.query
    |> option.to_result(Nil)
    |> result.then(uri.parse_query),
  )

  query
  |> dict.from_list
  |> dict.get("seed")
  |> result.then(rng.decode_seed)
}

pub fn init() -> Game {
  case get_seed() {
    Ok(seed) -> game_from_seed(seed)
    Error(Nil) -> {
      let seed = scenarios.random_winnable_scenario()
      let encoded_seed = rng.encode_seed(seed)
      io.println("seed=" <> encoded_seed)
      // window.set_location(window.self(), "?seed=" <> encoded_seed)

      game_from_seed(seed)
    }
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
          Game(
            ..game,
            current_state: state_after_move,
            moved_card:,
            previous_state:,
          )
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
    engine.Object(
      name: "blocking: " <> card_name(card),
      loc: Some(BlockingMinorArcanaFoundation),
      position:,
      size: Vec2(x: styles.card_size.y, y: styles.card_size.x),
      draw: fn(obj, context) {
        styles.draw_rotated_card(card, obj.position, -90.0, context)
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
