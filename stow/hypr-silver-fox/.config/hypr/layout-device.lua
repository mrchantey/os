-- silver-fox (Dell XPS 15 laptop): new windows fill the screen.
-- Standard master layout — a single window takes the whole monitor; extra
-- windows tile beside it. (Contrast: rainbow-cat opens a centered column.)
-- Required after the shared looknfeel.lua so it wins.
-- https://wiki.hypr.land/Configuring/Master-Layout/

hl.config({
  master = {
    new_status = "master",
    orientation = "left",
  },
})
