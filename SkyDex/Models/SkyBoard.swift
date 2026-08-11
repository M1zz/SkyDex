import Foundation

/// The board: forty-eight slots covering one day, laid out six across.
///
/// The colours are not hand-picked. They are sampled from a curve interpolated
/// in CIELAB between anchor colours at real moments — civil twilight, sunrise,
/// zenith, golden hour, sunset, afterglow — so neighbouring slots are a small
/// perceptual step apart and the filled board reads as one continuous
/// gradient rather than forty-eight decisions. Interpolating in RGB instead
/// would push the dawn blues through a muddy grey.
///
/// Slots are not equal lengths, because the sky does not change at an even
/// rate. The five hours after midnight get six beads; the three hours of
/// sunset and afterglow get twelve. Each band is a whole number of six-bead
/// rows, so a row never straddles two parts of the day — which is what lets
/// the board carry no labels at all and still read top to bottom as night,
/// dawn, day, sunset, night.
///
/// `band` survives only as a word for the detail sheets to use. Nothing groups
/// the grid by it.
enum SkyBoard {

    static let columns = 6

    static let slots: [SkySlot] = [
        SkySlot(id:  0, startMinute:    0, endMinute:   50, hex: "#080D18", band: "한밤"),
        SkySlot(id:  1, startMinute:   50, endMinute:  100, hex: "#090E1A", band: "한밤"),
        SkySlot(id:  2, startMinute:  100, endMinute:  150, hex: "#0A101D", band: "한밤"),
        SkySlot(id:  3, startMinute:  150, endMinute:  200, hex: "#0B1120", band: "한밤"),
        SkySlot(id:  4, startMinute:  200, endMinute:  250, hex: "#0D1423", band: "한밤"),
        SkySlot(id:  5, startMinute:  250, endMinute:  300, hex: "#131C32", band: "한밤"),
        SkySlot(id:  6, startMinute:  300, endMinute:  330, hex: "#242F4B", band: "여명"),
        SkySlot(id:  7, startMinute:  330, endMinute:  360, hex: "#38476B", band: "여명"),
        SkySlot(id:  8, startMinute:  360, endMinute:  390, hex: "#5A6B97", band: "여명"),
        SkySlot(id:  9, startMinute:  390, endMinute:  420, hex: "#8B9BBD", band: "여명"),
        SkySlot(id: 10, startMinute:  420, endMinute:  450, hex: "#9BADCB", band: "여명"),
        SkySlot(id: 11, startMinute:  450, endMinute:  480, hex: "#80A4CE", band: "여명"),
        SkySlot(id: 12, startMinute:  480, endMinute:  520, hex: "#709CCB", band: "낮"),
        SkySlot(id: 13, startMinute:  520, endMinute:  560, hex: "#5590C6", band: "낮"),
        SkySlot(id: 14, startMinute:  560, endMinute:  600, hex: "#4D8AC4", band: "낮"),
        SkySlot(id: 15, startMinute:  600, endMinute:  640, hex: "#3B80C0", band: "낮"),
        SkySlot(id: 16, startMinute:  640, endMinute:  680, hex: "#2F7BBE", band: "낮"),
        SkySlot(id: 17, startMinute:  680, endMinute:  720, hex: "#2875BA", band: "낮"),
        SkySlot(id: 18, startMinute:  720, endMinute:  760, hex: "#1D6DB4", band: "낮"),
        SkySlot(id: 19, startMinute:  760, endMinute:  800, hex: "#1F6EB5", band: "낮"),
        SkySlot(id: 20, startMinute:  800, endMinute:  840, hex: "#2573B6", band: "낮"),
        SkySlot(id: 21, startMinute:  840, endMinute:  880, hex: "#2A76B8", band: "낮"),
        SkySlot(id: 22, startMinute:  880, endMinute:  920, hex: "#347BBB", band: "낮"),
        SkySlot(id: 23, startMinute:  920, endMinute:  960, hex: "#4887C2", band: "낮"),
        SkySlot(id: 24, startMinute:  960, endMinute:  980, hex: "#508CC5", band: "늦은 오후"),
        SkySlot(id: 25, startMinute:  980, endMinute: 1000, hex: "#6798C9", band: "늦은 오후"),
        SkySlot(id: 26, startMinute: 1000, endMinute: 1020, hex: "#7CA4CC", band: "늦은 오후"),
        SkySlot(id: 27, startMinute: 1020, endMinute: 1040, hex: "#88A5C6", band: "늦은 오후"),
        SkySlot(id: 28, startMinute: 1040, endMinute: 1060, hex: "#ABA2A0", band: "늦은 오후"),
        SkySlot(id: 29, startMinute: 1060, endMinute: 1080, hex: "#C0A080", band: "늦은 오후"),
        SkySlot(id: 30, startMinute: 1080, endMinute: 1095, hex: "#C89B72", band: "노을"),
        SkySlot(id: 31, startMinute: 1095, endMinute: 1110, hex: "#D4915A", band: "노을"),
        SkySlot(id: 32, startMinute: 1110, endMinute: 1125, hex: "#D18750", band: "노을"),
        SkySlot(id: 33, startMinute: 1125, endMinute: 1140, hex: "#BD6239", band: "노을"),
        SkySlot(id: 34, startMinute: 1140, endMinute: 1155, hex: "#B15636", band: "노을"),
        SkySlot(id: 35, startMinute: 1155, endMinute: 1170, hex: "#95463E", band: "노을"),
        SkySlot(id: 36, startMinute: 1170, endMinute: 1185, hex: "#874243", band: "노을"),
        SkySlot(id: 37, startMinute: 1185, endMinute: 1200, hex: "#663B51", band: "노을"),
        SkySlot(id: 38, startMinute: 1200, endMinute: 1215, hex: "#5A3953", band: "노을"),
        SkySlot(id: 39, startMinute: 1215, endMinute: 1230, hex: "#45344F", band: "노을"),
        SkySlot(id: 40, startMinute: 1230, endMinute: 1245, hex: "#34304C", band: "노을"),
        SkySlot(id: 41, startMinute: 1245, endMinute: 1260, hex: "#302E49", band: "노을"),
        SkySlot(id: 42, startMinute: 1260, endMinute: 1290, hex: "#21233B", band: "밤"),
        SkySlot(id: 43, startMinute: 1290, endMinute: 1320, hex: "#161C31", band: "밤"),
        SkySlot(id: 44, startMinute: 1320, endMinute: 1350, hex: "#121829", band: "밤"),
        SkySlot(id: 45, startMinute: 1350, endMinute: 1380, hex: "#0C1120", band: "밤"),
        SkySlot(id: 46, startMinute: 1380, endMinute: 1410, hex: "#0A101D", band: "밤"),
        SkySlot(id: 47, startMinute: 1410, endMinute: 1440, hex: "#080D19", band: "밤"),
    ]

    static func slot(forMinute minute: Int) -> SkySlot {
        let clamped = min(1439, max(0, minute))
        return slots.last { $0.startMinute <= clamped } ?? slots[0]
    }

    static func slot(id: Int) -> SkySlot {
        slots.first { $0.id == id } ?? slots[0]
    }
}
