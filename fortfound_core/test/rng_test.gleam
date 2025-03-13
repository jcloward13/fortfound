import fortfound_core/rng
import gleam/int
import gleam/list
import startest/expect

pub fn shuffle_test() {
  let in_order = list.range(1, 1000)
  let shuffled = rng.shuffle(in_order, rng.random_seed())
  expect.to_not_equal(in_order, shuffled)
  expect.to_equal(in_order, list.sort(shuffled, int.compare))
}
