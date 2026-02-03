import fortfound_app/layout.{type Layout}
import fortfound_app/palette
import fortfound_app/special_characters.{suit_icon}
import fortfound_core/game.{empty_game, game_from_seed, get_card}
import fortfound_core/model.{
  type Card, type FullMove, type Game, type Location, type MajorArcanaFoundation,
  type MinorArcanaFoundation, type MoveToFoundation, type PartialMove, type Suit,
  BlockingMinorArcanaFoundation, Clubs, Coins, Column, Cups, Game, HistoryStep,
  MajorArcana, MinorArcana, MoveRequest, State, Swords,
}
import fortfound_core/rng.{type Seed}
import fortfound_core/scenarios
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import glector.{type Vector2, Vector2}
import lustre
import lustre/animation.{type Animation, type Animations}
import lustre/attribute.{type Attribute, attribute as attr}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event
import modem

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type SelectedCard {
  Dragging(
    card: Card,
    from: Location,
    position: Vector2,
    pointer_offset: Vector2,
  )
  Highlighted(card: Card, location: Location)
}

type AnimatedPosition {
  AnimatedPosition(xy: Vector2, z: Int)
}

type CardAnimations =
  Animations(Card, AnimatedPosition)

type CardAnimation =
  Animation(AnimatedPosition)

type Model {
  Model(
    game: Game,
    selected: Option(SelectedCard),
    animations: CardAnimations,
    displaying_help: Bool,
    layout: Layout,
    times_completed: Int,
  )
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  let game =
    modem.initial_uri()
    |> result.then(parse_seed)
    |> result.map(game_from_seed)
    |> result.lazy_unwrap(empty_game)

  #(
    Model(
      game:,
      selected: None,
      animations: animation.new(),
      displaying_help: False,
      layout: layout.get_layout(),
      times_completed: get_times_completed(),
    ),
    effect.none(),
  )
}

fn parse_seed(uri: Uri) -> Result(Seed, Nil) {
  use query <- result.try(
    uri.query
    |> option.to_result(Nil)
    |> result.then(uri.parse_query),
  )

  query
  |> dict.from_list
  |> dict.get("seed")
  |> result.then(rng.decode_seed)
}

type Scenario {
  Random
  Daily
  Specific(Seed)
}

type Msg {
  RequestedNewGame(Scenario)
  PressedRestart
  PressedHelp
  GrabbedCard(source: Location, position: Vector2, pointer_offset: Vector2)
  MovedPointer(Vector2)
  ReleasedCard(target: Option(Location))
  Clicked(Option(Location))
  UndoMove
  AnimationTick(Float)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let input_allowed = list.is_empty(animation.ids(model.animations))

  let #(new_model, effect) = case input_allowed, msg {
    _, RequestedNewGame(scenario) -> {
      let seed = case scenario {
        Random -> scenarios.random_winnable_scenario()
        Daily -> scenarios.current_daily_scenario()
        Specific(seed) -> seed
      }
      let game = game_from_seed(seed)
      let new_model = model |> start_game(game)
      #(new_model, set_seed_in_uri(seed))
    }

    _, PressedRestart -> {
      let new_model = case model.game.seed {
        None -> Model(..model, game: empty_game(), selected: None)
        Some(seed) -> {
          let game = game_from_seed(seed)
          model |> start_game(game)
        }
      }
      #(new_model, effect.none())
    }

    True, GrabbedCard(source:, position:, pointer_offset:) -> {
      let grabbed_card = get_card(model.game.state, source)
      let new_model = case model.selected, grabbed_card {
        None, Ok(card) -> {
          let dragging =
            Dragging(card:, from: source, position:, pointer_offset:)
          Model(..model, selected: Some(dragging))
        }
        _, _ -> model
      }
      #(new_model, effect.none())
    }

    True, MovedPointer(position) -> {
      let new_model = case model.selected {
        Some(Dragging(..) as dragging) -> {
          let position = glector.add(position, dragging.pointer_offset)
          let dragging = Dragging(..dragging, position:)
          Model(..model, selected: Some(dragging))
        }
        _ -> model
      }
      #(new_model, effect.none())
    }

    True, ReleasedCard(target: None) -> {
      let new_model = case model.selected {
        Some(Dragging(..)) -> Model(..model, selected: None)
        _ -> model
      }
      #(new_model, effect.none())
    }

    True, ReleasedCard(target: Some(target)) -> {
      let new_model = case model.selected {
        Some(Dragging(from: source, ..)) -> make_move(model, source, target)
        _ -> model
      }
      #(new_model, effect.none())
    }

    True, Clicked(Some(target)) -> {
      let new_model = case model.selected {
        Some(Highlighted(location: source, ..)) ->
          make_move(model, source, target)

        _ -> {
          case get_card(model.game.state, target) {
            Ok(card) -> {
              let highlighted = Highlighted(card:, location: target)
              Model(..model, selected: Some(highlighted))
            }
            Error(Nil) -> model
          }
        }
      }
      #(new_model, effect.none())
    }

    True, Clicked(None) -> #(Model(..model, selected: None), effect.none())

    _, UndoMove -> {
      let new_model = case model.game.history {
        [HistoryStep(state_before:, ..), ..history] -> {
          let game = Game(..model.game, state: state_before, history:)
          Model(..model, game:, animations: animation.new())
        }
        [] -> model
      }
      #(new_model, effect.none())
    }

    _, PressedHelp -> #(
      Model(..model, displaying_help: !model.displaying_help),
      effect.none(),
    )

    _, AnimationTick(t) -> #(
      Model(..model, animations: animation.tick(model.animations, t)),
      effect.none(),
    )

    False, _ -> #(model, effect.none())
  }

  let animation_tick_effect =
    animation.effect(new_model.animations, AnimationTick)
  #(new_model, effect.batch([effect, animation_tick_effect]))
}

fn start_game(model: Model, new_game: Game) -> Model {
  Model(
    ..model,
    game: new_game,
    selected: None,
    animations: animation.new()
      |> animation.schedule_many(card_draw_animations(
        new_game.state.columns,
        model.layout,
      )),
  )
}

fn set_seed_in_uri(seed: Seed) -> Effect(Msg) {
  let query = "seed=" <> rng.encode_seed(seed)
  modem.push("", Some(query), None)
}

fn card_draw_animations(
  columns: Dict(Int, List(Card)),
  layout: Layout,
) -> List(#(Card, CardAnimation)) {
  let start = Vector2(layout.column_x(5, layout), layout.foundations_y)

  columns
  |> dict.to_list
  |> list.sort(fn(column1, column2) { int.compare(column1.0, column2.0) })
  |> list.map(fn(column) {
    let #(column_index, cards) = column

    cards
    |> list.reverse
    |> list.index_map(fn(card, row) {
      let stop =
        Vector2(
          layout.column_x(column_index, layout),
          layout.tableau_card_y(row, layout),
        )

      #(card, stop)
    })
  })
  |> list.transpose
  |> list.flatten
  |> list.index_map(fn(card_and_stop, index) {
    let #(card, stop) = card_and_stop

    let interpolator = fn(t) {
      let xy = glector.lerp(start, stop, t)
      AnimatedPosition(xy:, z: -index)
    }
    let delay = 50.0 *. int.to_float(index)
    let duration = 200.0

    let animation =
      animation.create_delayed(after: delay, with: interpolator, for: duration)

    #(card, animation)
  })
}

fn stacked_card_move_animation(
  move: PartialMove,
  game_after_move: Game,
  index_in_stack: Int,
  moved_stack_size: Int,
  layout: Layout,
) -> #(Card, CardAnimation) {
  let assert #(Column(source_column), Column(target_column)) = #(
    move.source,
    move.target,
  )

  let assert Ok(source_column_size) =
    game_after_move.state.columns
    |> dict.get(source_column)
    |> result.map(list.length)

  let assert Ok(target_column_size) =
    game_after_move.state.columns
    |> dict.get(target_column)
    |> result.map(list.length)

  let row_offset = moved_stack_size - index_in_stack
  let source_row = source_column_size + row_offset - 1
  let target_row = target_column_size - row_offset

  let start =
    AnimatedPosition(
      xy: Vector2(
        layout.column_x(source_column, layout),
        layout.tableau_card_y(source_row, layout),
      ),
      z: moved_stack_size - index_in_stack,
    )

  let stop =
    AnimatedPosition(
      xy: Vector2(
        layout.column_x(target_column, layout),
        layout.tableau_card_y(target_row, layout),
      ),
      z: index_in_stack,
    )

  let interpolator = stacked_card_move_interpolator(start, stop)
  let delay = 100.0 *. int.to_float(index_in_stack)
  let duration = 200.0

  let animation =
    animation.create_delayed(after: delay, with: interpolator, for: duration)

  #(move.card, animation)
}

fn stacked_card_move_interpolator(
  start: AnimatedPosition,
  stop: AnimatedPosition,
) -> fn(Float) -> AnimatedPosition {
  fn(t) {
    let curvature = 0.5

    let xy =
      glector.lerp(start.xy, stop.xy, t)
      |> glector.add(Vector2(0.0, curvature *. t *. { 1.0 -. t }))

    let z =
      { stop.z - start.z }
      |> int.to_float
      |> float.multiply(t)
      |> float.round
      |> int.add(start.z)

    AnimatedPosition(xy:, z:)
  }
}

fn move_to_foundation_animation(
  move: MoveToFoundation,
  game_after_move: Game,
  index: Int,
  row_offset: Int,
  layout: Layout,
) -> #(Card, CardAnimation) {
  let start = case move.source {
    BlockingMinorArcanaFoundation -> {
      let foundation_center = layout.minor_arcana_foundation_center(layout)
      layout.center_to_origin(foundation_center, layout.card_size)
    }
    Column(i) -> {
      let assert Ok(column_size) =
        game_after_move.state.columns
        |> dict.get(i)
        |> result.map(list.length)
      Vector2(
        x: layout.column_x(i, layout),
        y: layout.tableau_card_y(column_size + row_offset, layout),
      )
    }
  }

  let assert Ok(stop_x) = case move.card {
    MajorArcana(value) -> {
      layout.major_arcana_foundation_xs(layout)
      |> list.drop(value)
      |> list.first
    }
    MinorArcana(suit:, ..) -> {
      layout.minor_arcana_foundation_xs(layout)
      |> list.drop(case suit {
        Clubs -> 0
        Coins -> 1
        Cups -> 2
        Swords -> 3
      })
      |> list.first
    }
  }
  let stop = Vector2(stop_x, layout.foundations_y)

  let interpolator = fn(t) {
    let xy = glector.lerp(start, stop, t *. t)
    AnimatedPosition(xy:, z: 0)
  }
  let delay = 200.0 *. int.to_float(index)
  let duration = 400.0

  let animation =
    animation.create_delayed(after: delay, with: interpolator, for: duration)

  #(move.card, animation)
}

fn animate_full_move(
  game_after_move: Game,
  layout: Layout,
  animations: CardAnimations,
  move: FullMove,
) -> CardAnimations {
  let new_animations =
    [
      move.stacked
        |> list.index_map(fn(partial_move, index_in_stack) {
          stacked_card_move_animation(
            partial_move,
            game_after_move,
            index_in_stack,
            list.length(move.stacked),
            layout,
          )
        }),
      move.to_foundations
        |> list.sort(by: fn(move1, move2) {
          case move1.source, move2.source {
            BlockingMinorArcanaFoundation, BlockingMinorArcanaFoundation ->
              order.Eq
            BlockingMinorArcanaFoundation, Column(_) -> order.Lt
            Column(_), BlockingMinorArcanaFoundation -> order.Gt
            Column(i1), Column(i2) -> int.compare(i1, i2)
          }
        })
        |> list.group(by: fn(move) { move.source })
        |> dict.values
        |> list.flat_map(fn(moves_from_same_location) {
          moves_from_same_location
          |> list.index_map(fn(move, i) {
            #(move, list.length(moves_from_same_location) - 1 + i)
          })
        })
        |> list.index_map(fn(move_and_offset, index) {
          let #(move, row_offset) = move_and_offset
          move_to_foundation_animation(
            move,
            game_after_move,
            index,
            row_offset,
            layout,
          )
        }),
    ]
    |> list.flatten

  animations |> animation.schedule_many(new_animations)
}

fn is_won(state: model.State) -> Bool {
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

fn make_move(model: Model, source: Location, target: Location) -> Model {
  case game.make_move(model.game, MoveRequest(source, target)) {
    Ok(#(move, game_after_move)) -> {
      let animations =
        animate_full_move(game_after_move, model.layout, model.animations, move)

      let times_completed = case is_won(game_after_move.state) {
        True -> {
          let new_count = model.times_completed + 1
          set_times_completed(new_count)
          new_count
        }
        False -> model.times_completed
      }

      Model(
        ..model,
        game: game_after_move,
        selected: None,
        animations:,
        times_completed:,
      )
    }

    Error(Nil) -> Model(..model, selected: None)
  }
}

fn view(model: Model) -> Element(Msg) {
  let State(
    major_arcana_foundation: major,
    columns:,
    minor_arcana_foundation: minor,
  ) = model.game.state

  case model.displaying_help {
    True -> view_help()
    False ->
      [
        case model.selected {
          Some(Dragging(card:, position:, ..)) ->
            view_dragged_card(card, position, model.layout)
          _ -> element.none()
        },
        view_animated_cards(model.animations, model.layout),
        view_major_arcana_foundation(major, model.layout, model.animations),
        view_buttons(model.layout),
        view_times_completed(model.times_completed, model.layout),
        case model.game.history {
          [HistoryStep(moved:, ..), ..] -> view_undo_button(moved, model.layout)
          _ -> element.none()
        },
        view_minor_arcana_foundation(
          minor,
          model.layout,
          model.selected,
          model.animations,
        ),
        view_columns(columns, model.layout, model.selected, model.animations),
      ]
      |> list.reverse
      |> svg(2000, 1000)
  }
}

fn bullet_list(items: List(String)) -> Element(Msg) {
  items
  |> list.map(fn(item) { html.li([], [html.text(item)]) })
  |> html.ul([], _)
}

fn link(text: String, href: String) -> Element(Msg) {
  html.a([attribute.href(href), attribute.style("color", palette.button_text)], [
    html.text(text),
  ])
}

fn view_help() -> Element(Msg) {
  html.div(
    [
      attribute.styles([
        #("margin", "5vh"),
        #("font-family", "Arima"),
        #("font-size", "1.75em"),
        #("color", palette.button_text),
      ]),
    ],
    [
      html.p([], [
        html.h2([], [
          html.text("This is a clone of "),
          link(
            "Zachtronics' Fortune's Foundation",
            "https://www.zachtronics.com/solitaire-collection/",
          ),
          html.text("."),
        ]),
      ]),
      html.p([], [
        bullet_list(["Your goal is to get all cards to their foundations."]),
      ]),
      html.p([], [
        bullet_list([
          "White cards are called Minor Arcanas and black cards are called Major Arcanas.",
          "Minor Arcanas' foundations go up by suit, from Ace to King.",
          "Major Arcanas' foundation goes simultaneously up from 0 and down from 21.",
        ]),
      ]),
      html.p([], [
        bullet_list([
          "Cards of the same kind (Major Arcanas or Minor Arcanas of the same suit) can be stacked in either ascending or descending order.",
          "You can only move one card at a time, but stacked cards will follow consecutively for your convenience.",
          "You can place one single card on top of the Minor Arcanas' foundations, blocking them temporarily.",
        ]),
      ]),
      html.p([], [
        html.text("This was made with "),
        link("Gleam", "https://gleam.run"),
        html.text(" and "),
        link("Lustre", "https://lustre.build"),
        html.text("."),
        html.br([]),
        html.text("Source code is available at "),
        link(
          "github.com/cauebs/fortfound",
          "https://github.com/cauebs/fortfound",
        ),
        html.text("."),
      ]),
      html.button(
        [
          attribute.styles([
            #("background", palette.button_fill),
            #("border", "3.5px solid " <> palette.button_stroke),
            #("border-radius", "5px"),
            #("padding", "1em"),
            #("color", palette.button_text),
            #("font-family", "Arima"),
            #("font-size", "1em"),
          ]),
          event.on_click(PressedHelp),
        ],
        [html.text("Return")],
      ),
    ],
  )
}

@external(javascript, "./fortfound_app_ffi.mjs", "screen_to_svg_percentage")
fn screen_to_svg_percentage(vector: Vector2) -> Vector2

@external(javascript, "./fortfound_app_ffi.mjs", "percentage_to_absolute")
fn percentage_to_absolute(vector: Vector2) -> Vector2

@external(javascript, "./fortfound_app_ffi.mjs", "get_times_completed")
fn get_times_completed() -> Int

@external(javascript, "./fortfound_app_ffi.mjs", "set_times_completed")
fn set_times_completed(count: Int) -> Nil

fn percentage_attribute(name: String, value: Float) -> Attribute(a) {
  attr(name, float.to_string(value *. 100.0) <> "%")
}

type MouseEvent {
  MouseDown
  MouseMove
  MouseUp
  MouseClick
}

fn on_mouse_event(event: MouseEvent, msg: fn(Vector2) -> Msg) -> Attribute(Msg) {
  let event_name = case event {
    MouseDown -> "mousedown"
    MouseMove -> "mousemove"
    MouseUp -> "mouseup"
    MouseClick -> "click"
  }

  event.on(
    event_name,
    event.mouse_position()
      |> decode.map(fn(xy) {
        let #(x, y) = xy
        Vector2(x, y)
      })
      |> decode.map(screen_to_svg_percentage)
      |> decode.map(msg),
  )
}

fn svg(elements: List(Element(Msg)), width: Int, height: Int) -> Element(Msg) {
  html.svg(
    [
      attr(
        "viewBox",
        [0, 0, width, height]
          |> list.map(int.to_string)
          |> string.join(" "),
      ),
      attribute.styles([
        #("width", "100%"),
        #("max-height", "100vh"),
        #("font-family", "Arima"),
        #("font-weight", "700"),
        #("font-size", "1.75em"),
        #("user-select", "none"),
      ]),
      on_mouse_event(MouseMove, MovedPointer),
      on_mouse_event(MouseUp, fn(_) { ReleasedCard(None) }),
    ],
    elements,
  )
}

fn card_text(card: Card) -> String {
  case card {
    MajorArcana(value) -> value |> int.to_string
    MinorArcana(suit, value) ->
      case value {
        1 -> "A"
        11 -> "J"
        12 -> "Q"
        13 -> "K"
        _ -> value |> int.to_string
      }
      <> suit_icon(suit)
  }
}

fn view_card(
  card card: Card,
  position position: Vector2,
  scale scale: Float,
  layout layout: Layout,
  loc loc: Option(Location),
) -> Element(Msg) {
  let size = layout.card_size |> glector.scale(scale)

  let #(text_x, text_anchor, text_dx) = case card {
    MajorArcana(_) -> #(position.x +. size.x /. 2.0, "middle", 0.0)
    MinorArcana(..) -> #(position.x, "start", layout.card_padding)
  }

  let fill_color = palette.card_fill(card)
  let main_color = palette.card_stroke(card)

  let rect =
    svg.rect([
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", fill_color),
      attr("stroke", main_color),
      attr("stroke-width", "3.5"),
    ])

  let text =
    svg.text(
      [
        percentage_attribute("x", text_x),
        percentage_attribute("y", position.y),
        percentage_attribute("dx", text_dx),
        percentage_attribute("dy", layout.card_padding),
        attr("text-anchor", text_anchor),
        attr("dominant-baseline", "hanging"),
        attr("fill", main_color),
      ],
      card_text(card),
    )

  svg.g(
    case loc {
      Some(loc) -> [
        on_mouse_event(MouseDown, fn(mouse_pos) {
          GrabbedCard(
            source: loc,
            position:,
            pointer_offset: glector.subtract(position, mouse_pos),
          )
        }),
        on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: Some(loc)) }),
        on_mouse_event(MouseClick, fn(_) { Clicked(Some(loc)) }),
      ]
      _ -> []
    },
    [rect, text],
  )
}

fn view_dragged_card(
  card: Card,
  position: Vector2,
  layout: Layout,
) -> Element(Msg) {
  svg.g([attribute.style("pointer-events", "none")], [
    view_card(card, position, 1.0, layout, None),
  ])
}

fn view_slot(
  position: Vector2,
  layout: Layout,
  target: Option(Location),
) -> Element(Msg) {
  svg.rect(
    [
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", layout.card_size.x),
      percentage_attribute("height", layout.card_size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", palette.slot_fill),
      attr("stroke", palette.slot_stroke),
      attr("stroke-width", "3.5"),
    ]
    |> list.append(case target {
      Some(loc) -> [
        on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: Some(loc)) }),
        on_mouse_event(MouseClick, fn(_) { Clicked(Some(loc)) }),
      ]
      None -> []
    }),
  )
}

fn view_button(
  text: String,
  position: Vector2,
  size: Vector2,
  msg: Msg,
) -> Element(Msg) {
  let text_x = position.x +. size.x /. 2.0
  let text_y = position.y +. size.y /. 2.0

  svg.g([attr("cursor", "pointer"), on_mouse_event(MouseDown, fn(_) { msg })], [
    svg.rect([
      percentage_attribute("x", position.x),
      percentage_attribute("y", position.y),
      percentage_attribute("width", size.x),
      percentage_attribute("height", size.y),
      attr("rx", "5"),
      attr("ry", "5"),
      attr("fill", palette.button_fill),
      attr("stroke", palette.button_stroke),
      attr("stroke-width", "3.5"),
    ]),
    svg.text(
      [
        percentage_attribute("x", text_x),
        percentage_attribute("y", text_y),
        attr("text-anchor", "middle"),
        attr("dominant-baseline", "middle"),
        attr("fill", palette.button_text),
      ],
      text,
    ),
  ])
}

fn view_buttons(layout: Layout) -> Element(Msg) {
  let buttons = {
    let specs =
      [
        #("New game", RequestedNewGame(Random)),
        #("Restart", PressedRestart),
        #("Daily", RequestedNewGame(Daily)),
        #("Help", PressedHelp),
      ]
      |> list.zip(layout.button_positions(layout))

    use #(#(text, msg), position) <- list.map(specs)
    view_button(text, position, layout.button_size, msg)
  }

  svg.g([], buttons)
}

fn view_times_completed(times_completed: Int, layout: Layout) -> Element(Msg) {
  let x = layout.column_x(5, layout) +. layout.card_size.x /. 2.0
  let y = layout.foundations_y +. layout.button_size.y /. 2.0

  svg.text(
    [
      percentage_attribute("x", x),
      percentage_attribute("y", y),
      attr("text-anchor", "middle"),
      attr("dominant-baseline", "middle"),
      attr("fill", palette.button_text),
      attr("font-size", "0.8em"),
    ],
    "Wins: " <> int.to_string(times_completed),
  )
}

fn view_undo_button(card: Card, layout: Layout) -> Element(Msg) {
  let card_scale = 0.7
  let button_size = layout.button_size |> glector.scale(0.8)

  let center =
    Vector2(layout.column_x(5, layout), layout.foundations_y)
    |> layout.origin_to_center(layout.card_size)

  let card_position =
    layout.center_to_origin(center, glector.scale(layout.card_size, card_scale))
  let button_position = layout.center_to_origin(center, button_size)

  svg.g([], [
    view_card(card, card_position, scale: card_scale, layout:, loc: None),
    view_button("Undo", button_position, button_size, UndoMove),
  ])
}

fn view_major_arcana_foundation(
  foundation: MajorArcanaFoundation,
  layout: Layout,
  animations: CardAnimations,
) -> Element(Msg) {
  let column_xs = layout.major_arcana_foundation_xs(layout)

  let view_cards = fn(cards: List(#(Card, Float))) -> List(Element(Msg)) {
    cards
    |> list.filter_map(fn(card_and_x) {
      let #(card, x) = card_and_x
      case is_animating(card, animations) {
        True -> Error(Nil)
        False -> {
          let position = Vector2(x, layout.foundations_y)
          Ok(view_card(card:, position:, scale: 1.0, layout:, loc: None))
        }
      }
    })
  }

  let assert Ok(low_slot_x) = list.first(column_xs)
  let low_slot =
    view_slot(Vector2(low_slot_x, layout.foundations_y), layout, None)

  let lows = case foundation.low {
    Some(low) -> {
      list.range(0, low)
      |> list.map(MajorArcana)
      |> list.zip(column_xs)
      |> view_cards
    }
    None -> {
      []
    }
  }

  let assert Ok(high_slot_x) = list.last(column_xs)
  let high_slot =
    view_slot(Vector2(high_slot_x, layout.foundations_y), layout, None)

  let highs = case foundation.high {
    Some(high) -> {
      list.range(21, high)
      |> list.map(MajorArcana)
      |> list.zip(list.reverse(column_xs))
      |> view_cards
    }
    None -> {
      []
    }
  }

  svg.g([], list.append([low_slot, ..lows], [high_slot, ..highs]))
}

fn view_minor_arcana_foundation(
  foundation: MinorArcanaFoundation,
  layout: Layout,
  selected: Option(SelectedCard),
  animations: CardAnimations,
) -> Element(Msg) {
  let column_xs = layout.minor_arcana_foundation_xs(layout)

  let cards = [
    highest_value_not_animating(Clubs, foundation.clubs, animations),
    highest_value_not_animating(Coins, foundation.coins, animations),
    highest_value_not_animating(Cups, foundation.cups, animations),
    highest_value_not_animating(Swords, foundation.swords, animations),
  ]

  let blocker_or_collider = case foundation.blocker, selected {
    Some(blocker), Some(Dragging(card: dragging, ..)) if blocker == dragging ->
      element.none()

    Some(blocker), _ ->
      case is_animating(blocker, animations) {
        True -> element.none()
        False -> view_blocker(blocker, layout)
      }

    None, _ -> {
      let assert Ok(x) = list.first(column_xs)
      let y = layout.foundations_y
      let assert Ok(width) =
        list.last(column_xs)
        |> result.map(float.add(_, layout.card_size.x /. 2.0))
      let height = layout.card_size.y

      let loc = Some(BlockingMinorArcanaFoundation)
      svg.rect([
        percentage_attribute("x", x),
        percentage_attribute("y", y),
        percentage_attribute("width", width),
        percentage_attribute("height", height),
        attr("fill", palette.transparent),
        on_mouse_event(MouseUp, fn(_) { ReleasedCard(target: loc) }),
        on_mouse_event(MouseClick, fn(_) { Clicked(loc) }),
      ])
    }
  }

  let foundation_cards =
    cards
    |> list.zip(column_xs)
    |> list.map(fn(card_and_x) {
      let #(card, x) = card_and_x
      let position = Vector2(x, layout.foundations_y)
      view_card(card:, position:, scale: 1.0, layout:, loc: None)
    })

  let elements = list.reverse([blocker_or_collider, ..foundation_cards])

  svg.g([], elements)
}

fn highest_value_not_animating(
  suit: Suit,
  max_value: Int,
  animations: CardAnimations,
) -> Card {
  let assert Ok(card) =
    list.range(1, max_value)
    |> list.map(MinorArcana(suit:, value: _))
    |> list.filter(fn(card) { !list.contains(animation.ids(animations), card) })
    |> list.last

  card
}

fn view_blocker(card: Card, layout: Layout) -> Element(Msg) {
  let foundation_center = layout.minor_arcana_foundation_center(layout)
  let position = layout.center_to_origin(foundation_center, layout.card_size)

  svg.g([rotate(foundation_center, 90.0)], [
    view_card(
      card:,
      position:,
      scale: 1.0,
      layout:,
      loc: Some(BlockingMinorArcanaFoundation),
    ),
  ])
}

fn rotate(position: Vector2, degrees: Float) -> Attribute(Msg) {
  let position = percentage_to_absolute(position)
  let rotation_values =
    [degrees, position.x, position.y]
    |> list.map(float.to_string)
    |> string.join(", ")

  attr("transform", "rotate(" <> rotation_values <> ")")
}

fn view_columns(
  columns: Dict(Int, List(Card)),
  layout: Layout,
  selected: Option(SelectedCard),
  animations: CardAnimations,
) -> Element(Msg) {
  columns
  |> dict.to_list
  |> list.map(view_column(_, layout, selected, animations))
  |> svg.g([], _)
}

fn view_column(
  column: #(Int, List(Card)),
  layout: Layout,
  selected: Option(SelectedCard),
  animations: CardAnimations,
) -> Element(Msg) {
  let #(column_index, cards) = column

  let x = layout.column_x(column_index, layout)
  let loc = Some(Column(column_index))

  let slot = view_slot(Vector2(x, layout.tableau_start.y), layout, loc)

  let cards =
    cards
    |> list.reverse
    |> list.index_map(fn(card, row) {
      let y = layout.tableau_card_y(row, layout)
      let position = case selected {
        Some(Dragging(card: dragging, ..)) if card == dragging -> Error(Nil)
        Some(Highlighted(card: highlighted, ..)) if card == highlighted -> {
          let offset = Vector2(0.0, layout.stacked_card_y_offset)
          Ok(Vector2(x, y) |> glector.add(offset))
        }
        _ ->
          case is_animating(card, animations) {
            True -> Error(Nil)
            False -> Ok(Vector2(x, y))
          }
      }
      let interactable = row == list.length(cards) - 1
      #(card, position, interactable)
    })
    |> list.filter_map(fn(spec) {
      let #(card, position, interactable) = spec
      use position <- result.map(position)
      let loc = case interactable {
        False -> None
        True -> loc
      }
      view_card(card:, position:, scale: 1.0, layout:, loc:)
    })

  svg.g([], [slot, ..cards])
}

fn is_animating(card: Card, animations: CardAnimations) -> Bool {
  animation.ids(animations) |> list.contains(card)
}

fn view_animated_cards(
  animations: CardAnimations,
  layout: Layout,
) -> Element(Msg) {
  animation.ids(animations)
  |> list.map(fn(card) {
    let assert Ok(position) = animations |> animation.value(card)
    #(
      position.z,
      view_card(card:, position: position.xy, scale: 1.0, layout:, loc: None),
    )
  })
  |> list.sort(fn(a, b) { int.compare(pair.first(a), pair.first(b)) })
  |> list.map(pair.second)
  |> svg.g([], _)
}
