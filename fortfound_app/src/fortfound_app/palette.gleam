import fortfound_core/model.{
  type Card, Clubs, Coins, Cups, MajorArcana, MinorArcana, Swords,
}

const transparent = "#00000000"

const dark_gold = "#8d693b"

pub const slot_stroke = dark_gold

// Must be transparent instead of 'none' otherwise events won't trigger.
pub const slot_fill = transparent

pub const major_arcana_stroke = "#eea96b"

pub const major_arcana_fill = "#282523"

pub const clubs = "#497327"

pub const coins = "#956f3f"

pub const cups = "#963728"

pub const swords = "#326973"

const beige = "#f8e3c1"

pub const minor_arcana_fill = beige

pub const button_fill = dark_gold

pub const button_text = beige

pub fn card_stroke(card: Card) -> String {
  case card {
    MajorArcana(_) -> major_arcana_stroke
    MinorArcana(Clubs, _) -> clubs
    MinorArcana(Coins, _) -> coins
    MinorArcana(Cups, _) -> cups
    MinorArcana(Swords, _) -> swords
  }
}

pub fn card_fill(card: Card) -> String {
  case card {
    MajorArcana(_) -> major_arcana_fill
    MinorArcana(..) -> minor_arcana_fill
  }
}
