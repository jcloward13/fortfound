import game
import gleam/int
import gleam/list
import sketch as s
import sketch/size.{type Size}

pub fn composed(classes: List(s.Class)) -> s.Class {
  classes |> list.map(s.compose) |> s.class
}

pub fn background_class() -> s.Class {
  s.class([
    s.background("#302017"),
    s.user_select("none"),
    s.height(size.vh(100)),
    s.padding(size.percent(2)),
  ])
}

pub type StackDirection {
  Horizontal
  Vertical
}

pub type GridRow {
  GridRow(Int)
}

pub type GridColumn {
  GridColumn(Int)
}

pub fn grid_row_from_index(index: Int, of total: Int) -> GridRow {
  GridRow(total - index)
}

pub fn grid_column_from_index(index: Int) -> GridColumn {
  GridColumn(index + 1)
}

fn grid_container_class(col_gap col_gap: Size) -> s.Class {
  s.class([s.display("grid"), s.column_gap(col_gap)])
}

pub fn major_arcana_foundation_class() -> s.Class {
  grid_container_class(col_gap: size.vh(3))
}

pub fn minor_arcana_foundation_class() -> s.Class {
  grid_container_class(col_gap: size.vh(3))
}

pub fn tableau_class() -> s.Class {
  grid_container_class(col_gap: size.vh(3))
}

pub fn grid_element_class(
  row: GridRow,
  col: GridColumn,
  direction: StackDirection,
  is_topmost: Bool,
) -> s.Class {
  let GridRow(row) = row
  let GridColumn(col) = col

  let #(aspect_ratio, border_overlap_style, row_span) = case
    is_topmost,
    direction
  {
    False, Vertical -> #(s.aspect_ratio("160 / 40"), s.border_bottom("none"), 1)
    False, Horizontal -> #(
      s.aspect_ratio("25 / 280"),
      s.border_right("none"),
      1,
    )
    True, _ -> #(s.aspect_ratio("160 / 280"), s.border("solid"), 7)
  }
  s.class([
    s.grid_row(int.to_string(row) <> "/ span " <> int.to_string(row_span)),
    s.grid_column(int.to_string(col)),
    aspect_ratio,
    border_overlap_style,
  ])
}

pub fn card_class() -> s.Class {
  s.class([
    s.border_style("solid"),
    s.padding(size.percent(3)),
    s.font_family("sans"),
    s.font_size(size.percent(140)),
    s.font_weight("bold"),
  ])
}

pub fn major_arcana_class() -> s.Class {
  let color = "#eea96b"
  s.class([
    s.background_color("#282523"),
    s.border_color(color),
    s.color(color),
    s.text_align("center"),
  ])
}

pub fn minor_arcana_class(suit: game.Suit) -> s.Class {
  let color = suit_color(suit)
  s.class([
    s.background_color("#f8e3c1"),
    s.border_color(color),
    s.color(color),
    s.text_align("left"),
  ])
}

fn suit_color(suit: game.Suit) -> String {
  case suit {
    game.Clubs -> "#497327"
    game.Coins -> "#956f3f"
    game.Cups -> "#963728"
    game.Swords -> "#326973"
  }
}

pub fn suit_icon(suit: game.Suit) -> String {
  case suit {
    game.Clubs -> "🌿"
    game.Coins -> "🪙"
    game.Cups -> "🍷"
    game.Swords -> "⚔️"
  }
}

pub fn selected_class() -> s.Class {
  s.class([
    s.transform("scale(1.1)"),
    s.box_shadow("5px -5px 7px 7px rgba(0, 0, 0, 0.2);"),
  ])
}

pub fn empty_slot_class() -> s.Class {
  s.class([s.border("solid"), s.border_color("#946e3e")])
}
