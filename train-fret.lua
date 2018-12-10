-- This code was written by Nikita Marchant <nikita.marchant@gmail.com>
-- Code under the 2-Clause BSD License https://opensource.org/licenses/BSD-2-Clause

api_version = 1

properties.max_speed_for_map_matching      = 220/3.6 -- 220kmph -> m/s
properties.weight_name                     = 'routability'
properties.left_hand_driving = true
properties.use_turn_restrictions = true

local config = {
  default_speed = 100,
  default_secondary_speed = 10,
  max_speed = 120,
  max_angle = 30,
  turn_time = 20,
}

function ternary ( cond , T , F )
    if cond then return T else return F end
end

function way_function(way, result)

  local data = {
    -- prefetch tags
    railway = way:get_value_by_key("railway"),
    service = way:get_value_by_key("service"),
    usage = way:get_value_by_key("usage"),
    name = way:get_value_by_key("name"),
    ref = way:get_value_by_key("ref"),
    maxspeed = tonumber(way:get_value_by_key("maxspeed")),
    oneway = way:get_value_by_key("oneway"),
    highspeed = way:get_value_by_key("highspeed"),
    trafic_mode = way:get_value_by_key("railway:traffic_mode"),
  }

  if (
    not data.railway or
    data.railway ~= 'rail' or
    data.usage == "military" or
    data.usage == "tourism"
  )
  then
    return
  end

  local is_secondary = (
    data.service == "siding" or
    data.service == "spur" or
    data.service == "crossover" or
    data.service == "yard" or
    data.usage == "branch" or
    data.usage == "industrial"
  )

  local is_highspeed = (
    data.highspeed or
    (data.maxspeed ~= nil and data.maxspeed > 220)
  )

  local is_freight_line = (
    data.usage == "freight" or
    data.trafic_mode == "freight"
  )

  local default_speed = ternary(is_secondary, config.default_secondary_speed, config.default_speed)
  local speed = ternary(data.maxspeed, data.maxspeed, default_speed)
  speed = math.min(speed, config.max_speed)

  result.forward_speed = speed
  result.backward_speed = speed

  result.forward_mode = mode.train
  result.backward_mode = mode.train

  result.forward_rate = 1
  result.backward_rate = 1

  if is_freight_line then
    result.forward_rate = 1.2
    result.backward_rate = 1.2
  elseif is_highspeed or is_secondary then
    result.forward_rate = 0.8
    result.backward_rate = 0.8
  end

  if data.oneway == "no" or data.oneway == "0" or data.oneway == "false" then
    -- both ways are ok, nothing to do
  elseif data.oneway == "-1" then
    -- opposite direction
    result.forward_mode = mode.inaccessible
  elseif data.oneway == "yes" or data.oneway == "1" or data.oneway == "true" then
    -- oneway
    result.backward_mode = mode.inaccessible
  end

  result.name = ternary(data.name, data.name, data.ref)

  result.forward_restricted = is_secondary
  result.backward_restricted = is_secondary


end


function node_function (node, result)
  local railway = node:get_value_by_key("railway")

  result.barrier = (railway == "buffer_stop" or railway == "derail")
  result.traffic_lights = false
end



function turn_function (turn)
  if (turn.angle > 180 + config.max_angle) or
     (turn.angle < 180 - config.max_angle)
  then
    return
  end

  turn.duration = config.turn_time
end
