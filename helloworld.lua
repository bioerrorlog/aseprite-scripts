-- Reference: https://behreajj.medium.com/how-to-script-aseprite-tools-in-lua-8f849b08733

local dlg = Dialog { title = "Hello World!" }

dlg:slider {
    id = "varName1",
    label = "Percent: ",
    min = 0,
    max = 100,
    value = 50
}

dlg:color {
    id = "varName2",
    label = "Color: ",
    color = Color(255, 128, 64, 255)
}

dlg:combobox {
    id = "varName3",
    label = "Weekday: ",
    option = "Friday",
    options = {
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday" }
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        print("Goodbye!")
        dlg:close()
    end
}

dlg:show { wait = false }
