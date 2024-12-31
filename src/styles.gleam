import gleam/float
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import kitten/color
import kitten/draw
import kitten/vec2.{type Vec2, Vec2}
import model.{
  type Card, type MajorArcanaFoundation, type MinorArcanaFoundation, type Suit,
  Clubs, Coins, Cups, MajorArcana, MinorArcana, Swords,
}

pub const card_size = Vec2(150.0, 260.0)

fn vertical_card_spacing() -> Float {
  card_size.y /. 7.0
}

fn card_vertices(position: Vec2) -> List(Vec2) {
  let Vec2(x, y) = position

  let half_size = card_size |> vec2.scale(0.5)
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

pub fn draw_slot(position: Vec2, context: draw.Context) -> Nil {
  let assert Ok(stroke_color) = color.from_hex("#8d693b")

  context
  |> draw.path(card_vertices(position), width: 3.0, color: stroke_color)
  Nil
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
    Clubs -> "🌿"
    Coins -> "🪙"
    Cups -> "🍷"
    Swords -> "⚔️"
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
      -. { card_size.x /. 2.0 }
      +. { size *. { text |> string.length |> int.to_float } /. 2.0 }
      +. { card_size.x /. 25.0 }
  }

  let y =
    tableau_card_position.y
    +. { card_size.y /. 2.0 }
    -. { vertical_card_spacing() /. 2.0 }
    -. { text_size() /. 2.75 }

  Vec2(x, y)
}

pub fn draw_card(card: Card, position: Vec2, context: draw.Context) -> Nil {
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
    card_vertices(position),
    width: card_size.y /. 65.0,
    color: stroke_color,
  )
  |> draw.text(
    card_text,
    card_text_position(card, position, card_text, text_size),
    size: text_size,
    weight: 900.0,
    font: "Verdana",
    tilt: 0.0,
    color: stroke_color,
  )
  Nil
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
  foundation: MajorArcanaFoundation,
  position: Vec2,
  context: draw.Context,
) -> Nil {
  let first_x = first_major_arcana_x()
  let last_x = last_major_arcana_x()
  let spacing = { last_x -. first_x } /. 22.0

  case foundation.low {
    Some(low) -> {
      {
        use value, index <- list.index_map(list.range(0, low))
        let x = first_x +. { spacing *. int.to_float(index) }
        draw_card(MajorArcana(value), position |> vec2.set_x(x), context)
      }
      Nil
    }
    _ -> draw_slot(position |> vec2.set_x(first_x), context)
  }

  case foundation.high {
    Some(high) -> {
      {
        use value, index <- list.index_map(list.range(21, high))
        let x = last_x -. { spacing *. int.to_float(index) }
        draw_card(MajorArcana(value), position |> vec2.set_x(x), context)
      }
      Nil
    }
    _ -> draw_slot(position |> vec2.set_x(last_x), context)
  }

  Nil
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
  card: Card,
  position: Vec2,
  angle: Float,
  context: draw.Context,
) -> Nil {
  context
  |> draw.set_camera_angle(angle)
  |> draw_card(card, position |> vec2.rotate_left, _)

  context
  |> draw.set_camera_angle(angle *. -1.0)

  Nil
}

pub fn draw_minor_arcana_foundation(
  foundation: MinorArcanaFoundation,
  position: Vec2,
  context: draw.Context,
) -> Nil {
  let cards = [
    MinorArcana(Clubs, foundation.clubs),
    MinorArcana(Coins, foundation.coins),
    MinorArcana(Cups, foundation.cups),
    MinorArcana(Swords, foundation.swords),
  ]
  let card_positions = minor_arcana_foundation_xs()

  use #(card, x) <- list.each(list.zip(cards, card_positions))
  draw_card(card, position |> vec2.set_x(x), context)
}
