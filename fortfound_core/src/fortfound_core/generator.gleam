import fortfound_core/game.{random_winnable_game}
import fortfound_core/model.{type Game}
import fortfound_core/serde
import gleam/io
import gleam/list
import gleam/otp/task

fn generate() -> Game {
  let game = random_winnable_game()
  io.debug(game.current_state |> serde.encode_state)
  game
}

fn generate_n_games(n: Int) -> List(Game) {
  list.range(1, n)
  |> list.map(fn(_) { task.async(generate) })
  |> list.map(task.await_forever)
}

pub fn main() {
  generate_n_games(16)
}
