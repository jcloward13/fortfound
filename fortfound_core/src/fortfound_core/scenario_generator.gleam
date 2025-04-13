import fortfound_core/game.{
  find_ready_for_foundation, game_from_seed, is_winnable,
}
import fortfound_core/model.{type Game}
import fortfound_core/rng.{random_seed}
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/otp/task.{type Task}

fn random_game() -> Game {
  let game = game_from_seed(random_seed())
  // Do not accept initial state where some cards can immediately go to foundations.
  case find_ready_for_foundation(game.state) {
    Ok(_) -> random_game()
    _ -> game
  }
}

fn random_winnable_game() -> Game {
  let game = random_game()
  case is_winnable(game.state) {
    True -> game
    False -> random_winnable_game()
  }
}

fn generate_n_games(n: Int) -> List(Task(Game)) {
  list.range(1, n)
  |> list.map(fn(_) { task.async(random_winnable_game) })
}

pub fn main() {
  use task <- list.each(generate_n_games(72))
  let game = task.await_forever(task)
  let assert Some(seed) = game.seed
  seed
  |> rng.encode_seed
  |> io.println
}
