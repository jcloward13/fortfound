import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import kitten/canvas
import kitten/color.{type Color}
import kitten/draw
import kitten/mouse
import kitten/simulate
import kitten/vec2.{type Vec2, Vec2}
import plinth/browser/window

pub type Object(loc) {
  Object(
    name: String,
    loc: Option(loc),
    position: Vec2,
    size: Vec2,
    draw: fn(Object(loc), draw.Context) -> Nil,
    clickable: Bool,
    draggable: Bool,
    targettable: Bool,
  )
}

type DraggedObject(loc) {
  DraggedObject(
    object: Object(loc),
    cursor_offset: Vec2,
    original_position: Vec2,
  )
}

type State(game, loc) {
  State(
    game_state: game,
    update_game: fn(game, Event(loc)) -> game,
    view_game: fn(game) -> List(Object(loc)),
    static_objects: List(Object(loc)),
    dragged_object: Option(DraggedObject(loc)),
    background: Color,
  )
}

fn init(
  init_game: fn() -> game,
  update_game: fn(game, Event(loc)) -> game,
  view_game: fn(game) -> List(Object(loc)),
  background: Color,
) -> State(game, loc) {
  let game_state = init_game()
  State(
    game_state:,
    update_game:,
    view_game:,
    static_objects: view_game(game_state),
    dragged_object: None,
    background:,
  )
}

pub type Event(loc) {
  Clicked(loc)
  Released(dragged: loc, target: loc)
}

fn find_closest_overlap(
  object: Object(loc),
  others: List(Object(loc)),
) -> Result(Object(loc), Nil) {
  others
  |> list.filter(fn(other) {
    other.targettable
    && simulate.is_overlapping(
      object.position,
      object.size,
      other.position,
      other.size,
    )
  })
  |> list.sort(by: fn(other1, other2) {
    float.compare(
      object.position |> vec2.dist(other1.position),
      object.position |> vec2.dist(other2.position),
    )
  })
  |> list.first
}

fn try_click_object(state: State(game, loc)) -> Option(Event(loc)) {
  let mouse_pos = mouse.pos()

  let clicked =
    state.static_objects
    |> list.find(fn(object) {
      object.clickable
      && simulate.is_within(mouse_pos, object.position, object.size)
    })

  case clicked {
    Ok(Object(loc: Some(loc), ..)) -> {
      Some(Clicked(loc))
    }
    _ -> None
  }
}

fn release_object_if_dragging(
  state: State(game, loc),
) -> #(State(game, loc), Option(Event(loc))) {
  case state.dragged_object {
    Some(DraggedObject(
      object: Object(
        loc: Some(source_loc),
        ..,
      ) as dragged,
      original_position:,
      ..,
    )) -> {
      let target = find_closest_overlap(dragged, state.static_objects)

      let #(new_position, event) = case target {
        Ok(Object(loc: Some(target_loc), position: new_position, ..)) -> #(
          new_position,
          Some(Released(source_loc, target_loc)),
        )
        _ -> #(original_position, None)
      }

      let released_object = Object(..dragged, position: new_position)
      let new_state =
        State(
          ..state,
          static_objects: [released_object, ..state.static_objects],
          dragged_object: None,
        )

      #(new_state, event)
    }

    _ -> #(state, None)
  }
}

fn try_move_dragged_object(state: State(game, loc)) -> State(game, loc) {
  case state.dragged_object {
    Some(dragged) -> {
      let new_position = mouse.pos() |> vec2.subtract(dragged.cursor_offset)
      let object = Object(..dragged.object, position: new_position)
      State(..state, dragged_object: Some(DraggedObject(..dragged, object:)))
    }
    _ -> state
  }
}

fn try_grab_object(state: State(game, loc)) -> State(game, loc) {
  let mouse_pos = mouse.pos()

  let hovered =
    state.static_objects
    |> list.find(fn(object) {
      object.draggable
      && simulate.is_within(mouse_pos, object.position, object.size)
    })

  case hovered {
    Ok(object) -> {
      let static_objects =
        state.static_objects
        |> list.filter(fn(other) { other != object })

      let dragged_object =
        Some(DraggedObject(
          object:,
          cursor_offset: mouse_pos |> vec2.subtract(object.position),
          original_position: object.position,
        ))

      State(..state, static_objects:, dragged_object:)
    }
    _ -> state
  }
}

fn update_game_with_event(
  state: State(game, loc),
  event: Option(Event(loc)),
) -> State(game, loc) {
  case event {
    Some(event) -> {
      let game_state = state.update_game(state.game_state, event)
      let static_objects = state.view_game(game_state)

      State(..state, game_state:, static_objects:)
    }
    _ -> state
  }
}

fn update(state: State(game, loc)) -> State(game, loc) {
  let state = case mouse.was_released(mouse.LMB) {
    True -> {
      let #(new_state, event) = release_object_if_dragging(state)
      update_game_with_event(new_state, event)
    }
    _ -> state
  }

  let state = case mouse.was_pressed(mouse.LMB) {
    True -> {
      let state = try_grab_object(state)
      let event = try_click_object(state)
      update_game_with_event(state, event)
    }
    _ -> state
  }

  state |> try_move_dragged_object
}

fn view(state: State(game, loc)) -> Nil {
  let context =
    draw.context()
    |> draw.background(state.background)

  state.static_objects
  |> list.reverse
  |> list.each(fn(object) { object.draw(object, context) })

  case state.dragged_object {
    Some(DraggedObject(object, ..)) -> object.draw(object, context)
    None -> Nil
  }

  Nil
}

fn get_window_size() -> Vec2 {
  let window = window.self()

  Vec2(
    window.inner_width(window) |> int.to_float,
    window.inner_height(window) |> int.to_float,
  )
}

fn scale_to_fit(content_size: Vec2, viewport_size: Vec2) -> Vec2 {
  let viewport_ratio = viewport_size.x /. viewport_size.y
  let content_ratio = content_size.x /. content_size.y

  case viewport_ratio >=. content_ratio {
    True -> Vec2(content_size.y *. viewport_ratio, content_size.y)
    False -> Vec2(content_size.x, content_size.x /. viewport_ratio)
  }
}

pub fn run(
  init_game: fn() -> game_state,
  update_game: fn(game_state, Event(obj_id)) -> game_state,
  view_game: fn(game_state) -> List(Object(obj_id)),
  canvas_id canvas_id: String,
  world_size world_size: Vec2,
  background background_color: Color,
) {
  let window_size = get_window_size()
  let canvas_size = world_size |> scale_to_fit(window_size)

  canvas.start_window(
    fn() { init(init_game, update_game, view_game, background_color) },
    update,
    view,
    canvas_id:,
    canvas_width: canvas_size.x,
    canvas_height: canvas_size.y,
    image_sources: [],
    sound_sources: [],
  )
}
