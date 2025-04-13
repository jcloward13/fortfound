function get_svg() {
    return document.getElementsByTagName("svg")[0];
}

function screen_to_svg_matrix(svg) {
    return svg.getScreenCTM().inverse();
}

function vector_as_svg_point(vector, svg) {
    let point = svg.createSVGPoint();
    point.x = vector.x;
    point.y = vector.y;
    return point;
}

function absolute_to_percentage(vector, svg) {
    let view_box = svg.viewBox.baseVal;
    return {
        x: vector.x / view_box.width,
        y: vector.y / view_box.height,
    };
}

export function screen_to_svg_percentage(vector) {
    let svg = get_svg();

    let point = vector_as_svg_point(vector, svg);
    let transform = screen_to_svg_matrix(svg);
    let new_point = point.matrixTransform(transform);
    return absolute_to_percentage(new_point, svg);
}

export function percentage_to_absolute(vector) {
    let svg = get_svg();
    let view_box = svg.viewBox.baseVal;

    return {
        x: vector.x * view_box.width,
        y: vector.y * view_box.height,
    };
}
