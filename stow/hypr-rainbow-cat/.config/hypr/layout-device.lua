-- rainbow-cat (ultrawide desktop): new windows open as a centered master column,
-- with slaves flanking it across the wide screen.
-- Required after the shared looknfeel.lua so it wins.
-- https://wiki.hypr.land/Configuring/Master-Layout/

hl.config({
  master = {
    new_status = "slave",
    slave_count_for_center_master = 0,
    orientation = "center",
    mfact = 0.5,
  },
})
