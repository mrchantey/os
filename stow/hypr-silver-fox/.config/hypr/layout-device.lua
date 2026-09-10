-- silver-fox (Dell Precision 7560 laptop): new windows fill the screen.
-- Standard master layout — a single window takes the whole monitor; extra
-- windows tile beside it. On a single 1920x1080 panel there is no room to give
-- away, which is exactly why this differs from rainbow-cat's centered column.
-- Required after the shared looknfeel.lua so it wins.
-- https://wiki.hypr.land/Configuring/Master-Layout/

hl.config({
  master = {
    new_status = "master",
    orientation = "left",
  },
})
