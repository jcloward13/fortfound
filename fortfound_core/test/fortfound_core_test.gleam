import fortfound_core/game.{game_from_seed, is_winnable}
import fortfound_core/model.{
  MajorArcana, MajorArcanaFoundation, MinorArcanaFoundation, State,
}
import fortfound_core/scenarios
import gleam/dict
import gleam/option.{None, Some}
import startest
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn won_test() {
  State(
    major_arcana_foundation: MajorArcanaFoundation(
      low: Some(10),
      high: Some(11),
    ),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 13,
      swords: 13,
      clubs: 13,
      cups: 13,
      blocker: None,
    ),
    columns: dict.from_list([
      #(0, []),
      #(1, []),
      #(2, []),
      #(3, []),
      #(4, []),
      #(5, []),
      #(6, []),
      #(7, []),
      #(8, []),
      #(9, []),
      #(10, []),
    ]),
  )
  |> is_winnable
  |> expect.to_be_true
}

pub fn trivially_winnable_test() {
  State(
    major_arcana_foundation: MajorArcanaFoundation(low: Some(8), high: Some(13)),
    minor_arcana_foundation: MinorArcanaFoundation(
      coins: 13,
      swords: 13,
      clubs: 13,
      cups: 13,
      blocker: None,
    ),
    columns: dict.from_list([
      #(0, [MajorArcana(10), MajorArcana(9)]),
      #(1, [MajorArcana(11), MajorArcana(12)]),
      #(2, []),
      #(3, []),
      #(4, []),
      #(5, []),
      #(6, []),
      #(7, []),
      #(8, []),
      #(9, []),
      #(10, []),
    ]),
  )
  |> is_winnable
  |> expect.to_be_true
}

pub fn winnable_example_test() {
  let game =
    scenarios.random_winnable_scenario()
    |> game_from_seed

  game.state
  |> is_winnable
  |> expect.to_be_true
}
