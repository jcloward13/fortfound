import fortfound_core/game.{game_from_seed, is_winnable}
import fortfound_core/scenarios
import startest
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn won_test() {
  scenarios.won_example()
  |> is_winnable
  |> expect.to_be_true
}

pub fn trivially_winnable_test() {
  scenarios.trivially_winnable_example()
  |> is_winnable
  |> expect.to_be_true
}

pub fn winnable_example_test() {
  let game =
    scenarios.random_winnable_scenario()
    |> game_from_seed

  game.current_state
  |> is_winnable
  |> expect.to_be_true
}
