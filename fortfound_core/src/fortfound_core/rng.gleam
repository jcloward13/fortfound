import gleam/int
import gleam/list
import gleam/result
import gleam/string
import prng/random
import prng/seed

pub type Seed {
  Seed(Int)
}

pub fn random_seed() -> Seed {
  random.int(0, random.max_int)
  |> random.random_sample
  |> Seed
}

fn to_prng_seed(seed: Seed) -> seed.Seed {
  let Seed(number) = seed
  seed.new(number)
}

pub fn encode_seed(seed: Seed) -> String {
  let Seed(number) = seed
  int.to_base36(number)
  |> string.pad_start(to: 6, with: "0")
}

pub fn decode_seed(seed_string: String) -> Result(Seed, Nil) {
  seed_string
  |> int.base_parse(36)
  |> result.map(Seed)
}

pub fn shuffle(items: List(a), seed: Seed) -> List(a) {
  let seed = seed |> to_prng_seed
  shuffle_aux(items, seed)
}

fn shuffle_aux(items: List(a), seed: seed.Seed) -> List(a) {
  case list.length(items) {
    0 -> []
    n -> {
      let #(index, new_seed) =
        random.int(0, n - 1)
        |> random.step(seed)

      let #(before, rest) = list.split(items, index)
      let assert #([chosen], after) = list.split(rest, 1)
      let remaining = list.append(before, after)

      [chosen, ..shuffle_aux(remaining, new_seed)]
    }
  }
}
