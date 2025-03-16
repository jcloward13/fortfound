import fortfound_core/model.{
  type Card, type MajorArcanaFoundation, type MinorArcanaFoundation, type Suit,
  Clubs, Coins, Cups, MajorArcana, MinorArcana, Swords,
}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import kitten/color
import kitten/draw
import kitten/math
import kitten/vec2.{type Vec2, Vec2}

pub fn background_color() -> color.Color {
  let assert Ok(color) = color.from_hex("#302017")
  color
}

pub const card_size = Vec2(150.0, 260.0)

fn vertical_card_spacing() -> Float {
  card_size.y /. 7.0
}

fn rect_vertices(position: Vec2, size: Vec2) -> List(Vec2) {
  let Vec2(x, y) = position

  let half_size = size |> vec2.scale(0.5)
  let Vec2(half_width, half_height) = half_size

  let vertices = [
    Vec2(x -. half_width, y +. half_height),
    position |> vec2.add(half_size),
    Vec2(x +. half_width, y -. half_height),
    position |> vec2.subtract(half_size),
  ]

  vertices
  |> list.append(vertices |> list.take(2))
  // Repeat first so that loop closes.
  // Repeat second so that first corner looks pointy as well.
}

pub fn draw_slot(context: draw.Context, position: Vec2) -> draw.Context {
  let assert Ok(stroke_color) = color.from_hex("#8d693b")

  context
  |> draw.path(
    rect_vertices(position, card_size),
    width: 3.0,
    color: stroke_color,
  )
}

fn suit_color(suit: Suit) -> String {
  case suit {
    Clubs -> "#497327"
    Coins -> "#956f3f"
    Cups -> "#963728"
    Swords -> "#326973"
  }
}

pub fn suit_icon(suit: Suit) -> String {
  case suit {
    Clubs -> "♣"
    Coins -> "♦"
    Cups -> "♥"
    Swords -> "♠"
  }
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

fn text_size() -> Float {
  vertical_card_spacing() *. 0.75
}

fn card_text_position(
  card: Card,
  tableau_card_position: Vec2,
  text: String,
  size: Float,
) -> Vec2 {
  let x = case card {
    MajorArcana(..) -> tableau_card_position.x
    MinorArcana(..) ->
      tableau_card_position.x
      -. { card_size.x *. 0.375 }
      +. { size *. { text |> string.length |> int.to_float } *. 0.2 }
  }

  let y =
    tableau_card_position.y
    +. { card_size.y /. 2.0 }
    -. { vertical_card_spacing() /. 2.0 }
    -. { text_size() /. 2.75 }

  Vec2(x, y)
}

pub fn draw_card(
  context: draw.Context,
  card: Card,
  position: Vec2,
) -> draw.Context {
  let assert Ok(fill_color) =
    case card {
      MajorArcana(_) -> "#282523"
      MinorArcana(_, _) -> "#f8e3c1"
    }
    |> color.from_hex

  let assert Ok(stroke_color) =
    case card {
      MajorArcana(_) -> "#eea96b"
      MinorArcana(suit, _) -> suit_color(suit)
    }
    |> color.from_hex

  let card_text = card_text(card)
  let text_size = text_size()

  context
  |> draw.rect(position, size: card_size, color: fill_color)
  |> draw.path(
    rect_vertices(position, card_size),
    width: card_size.y /. 65.0,
    color: stroke_color,
  )
  |> draw.text(
    card_text,
    card_text_position(card, position, card_text, text_size),
    size: text_size,
    weight: 700.0,
    font: "Arima",
    tilt: 0.0,
    color: stroke_color,
  )
}

pub fn tableau_card_position(
  column_index column_index: Int,
  card_index card_index: Int,
) -> Vec2 {
  let x = int.to_float(column_index - 5) *. card_size.x *. 1.2
  let y = 60.0 -. int.to_float(card_index) *. vertical_card_spacing()
  Vec2(x, y)
}

fn foundations_y() -> Float {
  500.0 -. card_size.y /. 2.0
}

fn first_major_arcana_x() -> Float {
  tableau_card_position(column_index: 0, card_index: 0).x
}

fn last_major_arcana_x() -> Float {
  tableau_card_position(column_index: 3, card_index: 0).x
}

pub fn major_arcana_foundation_position() -> Vec2 {
  let x = { first_major_arcana_x() +. last_major_arcana_x() } /. 2.0

  Vec2(x:, y: foundations_y())
}

pub fn major_arcana_foundation_size() -> Vec2 {
  let width = { last_major_arcana_x() -. first_major_arcana_x() } +. card_size.x
  Vec2(x: width, y: card_size.y)
}

pub fn draw_major_arcana_foundation(
  context: draw.Context,
  foundation: MajorArcanaFoundation,
  position: Vec2,
) -> draw.Context {
  let first_x = first_major_arcana_x()
  let last_x = last_major_arcana_x()
  let spacing = { last_x -. first_x } /. 22.0

  case foundation.low {
    Some(low) -> {
      {
        use value, index <- list.index_map(list.range(0, low))
        let x = first_x +. { spacing *. int.to_float(index) }
        context |> draw_card(MajorArcana(value), position |> vec2.set_x(x))
      }
      context
    }
    _ -> context |> draw_slot(position |> vec2.set_x(first_x))
  }

  case foundation.high {
    Some(high) -> {
      {
        use value, index <- list.index_map(list.range(21, high))
        let x = last_x -. { spacing *. int.to_float(index) }
        context |> draw_card(MajorArcana(value), position |> vec2.set_x(x))
      }
      context
    }
    _ -> context |> draw_slot(position |> vec2.set_x(last_x))
  }
}

fn minor_arcana_foundation_xs() -> List(Float) {
  use column_index <- list.map(list.range(7, 10))
  tableau_card_position(column_index:, card_index: 0).x
}

pub fn minor_arcana_foundation_position() -> Vec2 {
  let card_positions = minor_arcana_foundation_xs()

  let assert Ok(x) = {
    card_positions
    |> list.reduce(float.add)
    |> result.then(float.divide(_, by: 4.0))
  }

  Vec2(x:, y: foundations_y())
}

pub fn minor_arcana_foundation_size() -> Vec2 {
  let card_positions = minor_arcana_foundation_xs()

  let assert #(Ok(first_x), Ok(last_x)) = #(
    list.first(card_positions),
    list.last(card_positions),
  )

  let width = { last_x -. first_x } +. card_size.x
  Vec2(x: width, y: card_size.y)
}

pub fn draw_rotated_card(
  context: draw.Context,
  card: Card,
  position: Vec2,
  degrees: Float,
) -> draw.Context {
  let angle = math.deg_to_rad(degrees)

  context
  |> draw.set_camera_angle(angle)
  |> draw_card(card, position |> vec2.rotate_left)
  |> draw.set_camera_angle(angle *. -1.0)
}

pub fn draw_scaled_card(
  context: draw.Context,
  card: Card,
  position: Vec2,
  scale: Float,
) -> draw.Context {
  context
  |> draw.set_camera_pos(vec2.invert(position))
  |> draw.set_camera_scale(scale)
  |> draw_card(card, Vec2(0.0, 0.0))
  |> draw.set_camera_scale(1.0 /. scale)
  |> draw.set_camera_pos(position)
}

pub fn draw_minor_arcana_foundation(
  context: draw.Context,
  foundation: MinorArcanaFoundation,
  position: Vec2,
) -> draw.Context {
  let cards = [
    MinorArcana(Clubs, foundation.clubs),
    MinorArcana(Coins, foundation.coins),
    MinorArcana(Cups, foundation.cups),
    MinorArcana(Swords, foundation.swords),
  ]
  let card_positions = minor_arcana_foundation_xs()

  {
    use #(card, x) <- list.each(list.zip(cards, card_positions))
    context |> draw_card(card, position |> vec2.set_x(x))
  }
  context
}

pub fn button_size() -> Vec2 {
  let text_size = text_size()
  Vec2(text_size *. 4.8, text_size *. 2.5)
}

fn button_stroke_color() -> color.Color {
  let assert Ok(color) = color.from_hex("#eea96b")
  color
}

fn draw_button(context: draw.Context, position: Vec2) -> draw.Context {
  let size = button_size()
  context
  |> draw.path(
    rect_vertices(position, size),
    width: 5.0,
    color: button_stroke_color(),
  )
  |> draw.rect(pos: position, size:, color: background_color())
}

pub fn new_game_button_position() -> Vec2 {
  let x = { last_major_arcana_x() +. undo_button_position().x } /. 2.0
  Vec2(x, foundations_y())
}

pub fn draw_new_game_button(
  context: draw.Context,
  position: Vec2,
) -> draw.Context {
  let size = text_size()
  let text_color = button_stroke_color()

  context
  |> draw_button(position)
  |> draw.text(
    text: "New",
    pos: position |> vec2.add_y(size *. 0.2),
    size:,
    tilt: 0.0,
    font: "Arima",
    weight: 600.0,
    color: text_color,
  )
  |> draw.text(
    text: "game",
    pos: position |> vec2.subtract_y(size *. 0.8),
    size:,
    tilt: 0.0,
    font: "Arima",
    weight: 600.0,
    color: text_color,
  )
}

pub fn undo_button_position() -> Vec2 {
  vec2.add(
    major_arcana_foundation_position(),
    minor_arcana_foundation_position(),
  )
  |> vec2.scale(0.5)
}

const undo_button_card_scale: Float = 0.6

pub fn undo_button_size() -> Vec2 {
  card_size |> vec2.scale(undo_button_card_scale)
}

pub fn draw_undo_button(
  context: draw.Context,
  moved_card: Card,
  position: Vec2,
) -> draw.Context {
  let size = text_size()
  let text_color = button_stroke_color()

  context
  |> draw_scaled_card(moved_card, position, undo_button_card_scale)
  |> draw_button(position)
  |> draw.text(
    text: "Undo",
    pos: position |> vec2.subtract_y(size *. 0.3),
    size:,
    tilt: 0.0,
    font: "Arima",
    weight: 600.0,
    color: text_color,
  )
}

pub fn daily_challenge_button_position() -> Vec2 {
  let assert Ok(first_minor_arcana_foundation_x) =
    list.first(minor_arcana_foundation_xs())

  let x = { undo_button_position().x +. first_minor_arcana_foundation_x } /. 2.0
  Vec2(x, foundations_y())
}

pub fn draw_daily_challenge_button(
  context: draw.Context,
  position: Vec2,
) -> draw.Context {
  let size = text_size()
  let text_color = button_stroke_color()

  context
  |> draw_button(position)
  |> draw.text(
    text: "Daily",
    pos: position |> vec2.add_y(size *. 0.2),
    size:,
    tilt: 0.0,
    font: "Arima",
    weight: 600.0,
    color: text_color,
  )
  |> draw.text(
    text: "challenge",
    pos: position |> vec2.subtract_y(size *. 0.8),
    size:,
    tilt: 0.0,
    font: "Arima",
    weight: 600.0,
    color: text_color,
  )
}
