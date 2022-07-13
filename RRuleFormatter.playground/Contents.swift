import Foundation

var rRule = RRule(frequency: .weekly)
rRule.byDay = [.monday, .wednesday, .friday]
let rRuleFormatter = RRuleFormatter()
var rRuleString = rRuleFormatter.string(from: rRule)
rRule.interval = 10
rRuleString = rRuleFormatter.string(from: rRule)

let str = "asdf"
let df = DateFormatter()
//df.dateStyle = .medium
print(df.string(from: .now))
