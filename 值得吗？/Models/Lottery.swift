import Foundation
import Observation

enum DrawEmotion: String, CaseIterable, Codable, Identifiable {
    case excited = "激动", happy = "高兴", sad = "伤心", grieving = "悲痛", neutral = "无感"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .excited: "bolt.heart"; case .happy: "sun.max"; case .sad: "cloud.drizzle"; case .grieving: "heart"; case .neutral: "wind" }
    }
    var guidance: String {
        switch self {
        case .excited: "先把呼吸放慢，事实和感觉可以分开看。今天不必急着拍板。"
        case .happy: "带着好心情来，给今天留一点小小的仪式。"
        case .sad: "难过时不必勉强振作，让这支签陪你歇一会儿。"
        case .grieving: "你不需要立刻走出来。此刻先照顾自己，慢慢来就好。"
        case .neutral: "不用寻找特别的感觉，一支签也可以只是片刻停留。"
        }
    }
}

enum DrawMode: String, Codable, CaseIterable, Identifiable {
    case original, guanyin
    var id: String { rawValue }
    var title: String { self == .original ? "问心签" : "观音灵签" }
}

struct CulturalLot: Identifiable {
    let id: Int
    let name: String
    let poem: String
    let meaning: String
    let action: String
    static let all: [Self] = [
        .init(id: 1, name: "云开见月", poem: "浮云随水去\n明月照归途\n且把心安住\n微光亦可扶", meaning: "眼前的杂乱未必需要立刻理清。把目光收回到一件可以完成的小事，答案常在行动中慢慢清楚。", action: "把当前的事情分成事实、猜测、下一步，各写一句。"),
        .init(id: 2, name: "轻舟缓行", poem: "轻舟停晚渡\n岸柳拂衣襟\n不赶千重浪\n先听一水音", meaning: "缓一缓也是前进。看清自己的体力、资源和方向，比赶上别人的节奏更重要。", action: "给正在犹豫的事留一晚，明天再检查自己的想法。"),
        .init(id: 3, name: "灯火可亲", poem: "一灯留小院\n细雨润青苔\n莫问春何处\n温茶待客来", meaning: "支撑有时来自很小的日常。让一顿饭、一杯水或一个可信赖的人，先接住今天的你。", action: "做一件照顾自己的小事，或者给信任的人发一句问候。"),
        .init(id: 4, name: "竹影清风", poem: "竹影摇疏窗\n清风不问名\n心中留寸地\n容得万山青", meaning: "给自己留一点空白，不必对所有事情立即回应。边界能让关系和生活更从容。", action: "找一件可以晚些回复的事，给自己留十分钟安静。"),
        .init(id: 5, name: "溪桥春信", poem: "溪桥连远岸\n新绿上枝头\n一步寻常路\n也能解旧愁", meaning: "改变可以从很小的一步开始。无需一次走到远处，先试一试脚下这块石头是否稳当。", action: "选择一个成本可控的小尝试，写下完成标准。"),
        .init(id: 6, name: "静水照心", poem: "静水映天光\n微波自有章\n不争一时快\n心定路渐长", meaning: "把一时的热度和长久的愿望放在一起看看。真正想要的东西，通常经得起一点等待。", action: "问自己：如果没有人知道，我还愿意做这件事吗？"),
        .init(id: 7, name: "小满知足", poem: "麦穗迎风立\n庭前日渐长\n人间多小满\n留白亦生香", meaning: "不必等到所有事情圆满，才允许自己休息。看见已经拥有的，也看见尚有余地的地方。", action: "记录一件今天已经做到的小事。"),
        .init(id: 8, name: "山径有光", poem: "山径转还深\n林间有鸟音\n莫催花尽放\n且护此时心", meaning: "暂时看不到全貌并不等于走错路。先核实一个关键问题，再决定下一步投入多少。", action: "找一个可靠的信息来源，核对最在意的那个假设。"),
        .init(id: 9, name: "檐雨初歇", poem: "檐雨滴声缓\n苔阶映晓晴\n旧事轻轻放\n新芽慢慢生", meaning: "放下有自己的速度，情绪也有自己的节奏。你可以边休息边继续生活，不必给自己设期限。", action: "把最想被理解的一句话写下来，先不急着评判。"),
        .init(id: 10, name: "松间听风", poem: "松间风过处\n石上坐闲身\n天地皆留白\n从容看此春", meaning: "片刻停留能让注意力回到眼前。别人的期待可以听见，你自己的需要也值得被认真对待。", action: "放下屏幕一分钟，观察周围三样真实的事物。"),
        .init(id: 11, name: "星河有渡", poem: "星河铺远水\n渡口有归灯\n一念存温厚\n长夜亦可行", meaning: "不必一个人扛住所有事情。向值得信任的人说明需要，是一种照顾自己、也让关系更真实的方式。", action: "试着向一个可信赖的人提出具体、可实现的小请求。"),
        .init(id: 12, name: "花信徐来", poem: "花信过疏篱\n春风细细吹\n且将根养好\n不必问花期", meaning: "把注意力放到可积累的事情上：睡眠、学习、资源和支持。稳定的准备，比反复猜测结果更有用。", action: "为一件长期重要的小事，安排一个十分钟的时段。"),
        .init(id: 13, name: "柳岸回青", poem: "柳岸新芽短\n春潮入梦轻\n不须催远客\n先把旧窗明", meaning: "改变不必声势浩大。收拾一处熟悉的角落，也是在为下一步留出空间。", action: "整理一件搁置的小事，再决定今天最重要的一步。"),
        .init(id: 14, name: "石阶听雨", poem: "石阶留雨痕\n竹叶落无声\n暂歇奔波意\n回身见小晴", meaning: "停下来观察，能让模糊的担忧变得具体。把感觉写清楚，再分辨哪些需要处理。", action: "把一个担忧分成事实和猜测两栏。"),
        .init(id: 15, name: "白帆待风", poem: "白帆依岸静\n远水接天青\n未借长风起\n先将绳缆清", meaning: "等待不等于停滞。适合出发之前，可以先把资源和边界确认好。", action: "检查下一步的时间、成本和退出办法。"),
        .init(id: 16, name: "桃溪问路", poem: "桃溪分两岸\n小径绕疏篱\n问路逢樵子\n归来有所知", meaning: "不熟悉的路可以问一问。求助不是把决定交给别人，而是补上自己的信息。", action: "向有经验的人提出一个具体问题。"),
        .init(id: 17, name: "茶烟午后", poem: "茶烟浮午后\n日影到书边\n闲坐三分静\n心宽一寸天", meaning: "你不必在每个时刻都高效。给身体和注意力一个短暂的休息，再回到眼前。", action: "留出五分钟，不安排任何任务。"),
        .init(id: 18, name: "远岫初晴", poem: "远岫云初散\n松窗日正明\n且看来时路\n一步亦成行", meaning: "回看已经走过的部分，可以帮助你看见真实的积累。下一步不需要证明全部。", action: "写下一项已经具备的准备。"),
        .init(id: 19, name: "荷塘见微", poem: "荷叶承清露\n微风过小塘\n一痕新水绿\n也可入诗章", meaning: "细小的变化也有价值。留意让你舒服一点的线索，看看它能否重复。", action: "记录一件带来轻松的小事。"),
        .init(id: 20, name: "归雁有序", poem: "归雁行天阔\n秋云不系舟\n各循心上路\n未必共潮头", meaning: "别人的速度不必成为你的刻度。按现实条件调整节奏，是一种负责。", action: "为一个目标重新设定合适的期限。"),
        .init(id: 21, name: "梅枝待暖", poem: "梅枝临小院\n雪尽有余香\n不问开多少\n先将根护长", meaning: "先照顾支撑你的日常，再考虑更大的目标。睡眠、吃饭和支持同样重要。", action: "为今天安排一顿安稳的饭。"),
        .init(id: 22, name: "桥边灯影", poem: "桥边灯影小\n夜水自徐行\n若怕前途暗\n同行可问声", meaning: "不知道下一步时，可以先找一个可信赖的人讨论。被听见也是一种支持。", action: "告诉信任的人你希望得到哪一种帮助。"),
        .init(id: 23, name: "雨后闻莺", poem: "雨后闻莺早\n庭前草色新\n旧愁容暂放\n好景慢相亲", meaning: "短暂的轻松不需要抵消所有难过。你可以同时带着复杂感受生活。", action: "用两个词描述此刻不同的感受。"),
        .init(id: 24, name: "松籽入土", poem: "松籽藏深土\n微光照远林\n年年添寸许\n莫问一朝阴", meaning: "长期的事情需要小而稳定的投入。让目标有可持续的节奏，比一次用尽力气更实在。", action: "给长期目标安排十分钟。"),
        .init(id: 25, name: "书页生风", poem: "书页翻新意\n清风入短檐\n未知先记下\n留待细寻看", meaning: "不懂的地方可以先记录，不必马上给出答案。问题本身能带你找到下一条线索。", action: "写下一个想核实的问题。"),
        .init(id: 26, name: "江湾泊舟", poem: "江湾容小泊\n岸阔水声低\n暂把行囊卸\n明朝再问期", meaning: "休息不必等到任务全部完成。暂缓一项低优先级安排，可能让重要的事更清楚。", action: "把一件今天可以不做的事延后。"),
        .init(id: 27, name: "桂影移窗", poem: "桂影移窗慢\n清香过短墙\n有心留一刻\n不负此时光", meaning: "把注意力留给正在发生的交流。片刻专心，胜过同时处理许多事情。", action: "与人交流时把手机放远一点。"),
        .init(id: 28, name: "苔石藏泉", poem: "苔石藏泉细\n山深路不穷\n低头寻水脉\n先辨往来踪", meaning: "问题看似复杂时，先找最关键的一个环节。核实它，往往比同时猜所有可能更有用。", action: "选出最影响判断的一项事实并核实。"),
        .init(id: 29, name: "晨炊有暖", poem: "晨炊生小巷\n热气到窗前\n日子从容过\n寻常亦可怜", meaning: "平常的照顾也值得珍惜。不要把所有心力都押在某个尚未发生的结果上。", action: "为熟悉的日常留一点认真。"),
        .init(id: 30, name: "云舟随岸", poem: "云舟随岸转\n水阔不争先\n收放皆有度\n归来月正圆", meaning: "行进中也可以调整计划。改变方法并不抹去已经付出的认真。", action: "允许一个不再合适的计划做小幅调整。"),
        .init(id: 31, name: "篱下新菊", poem: "篱下新菊小\n秋深色未迟\n人间多次第\n且待合宜时", meaning: "不必拿不同阶段的自己比较。把评价放回自己的条件和目标里。", action: "用自己的标准写下今天的一点进展。"),
        .init(id: 32, name: "清溪见底", poem: "清溪见底石\n流水各分明\n愿把心头事\n平平写一程", meaning: "把想要、担忧和责任分别写下来，可能更容易看清取舍。", action: "把正在犹豫的事列成三栏。"),
        .init(id: 33, name: "落日留霞", poem: "落日留霞暖\n长亭有晚风\n此行虽暂歇\n回望亦从容", meaning: "结束一段安排也可以是有意识的选择。先看它是否仍符合你现在的需要。", action: "检查一项承诺是否需要重新商量。"),
        .init(id: 34, name: "山花无约", poem: "山花无约开\n小径自成蹊\n偶得闲中趣\n不须问所期", meaning: "有些体验可以先感受，不急着衡量意义。给生活留一点没有成果要求的空间。", action: "做十分钟只因为喜欢的事情。"),
        .init(id: 35, name: "石鼎温茶", poem: "石鼎温茶熟\n窗前一卷书\n心忙先缓缓\n话到静时舒", meaning: "重要的表达可以等到你更平稳的时候。先整理想说什么，再决定如何开口。", action: "把一段想说的话先写下来。"),
        .init(id: 36, name: "鹭影平沙", poem: "鹭影平沙浅\n潮来又自平\n进退留余地\n长路好同行", meaning: "界限让合作更持久。说明能做什么，也说明需要哪些条件。", action: "为一项请求写出清楚的可接受范围。"),
        .init(id: 37, name: "桑榆向晚", poem: "桑榆迎晚照\n归鸟识林深\n忙尽寻常事\n还留一寸心", meaning: "忙碌之外，自己的需要也值得安排。你不必只在剩余时间里照顾自己。", action: "为今晚留出一段休息。"),
        .init(id: 38, name: "溪亭小坐", poem: "溪亭临曲水\n风静见游鱼\n若问身何处\n先知此刻居", meaning: "当想法跑得太远，先回到周围可见的事物。让注意力有一个落点。", action: "观察眼前三种颜色。"),
        .init(id: 39, name: "木兰待渡", poem: "木兰停渡口\n江上有晴波\n未识风来处\n先将路细磨", meaning: "新的机会可以先做小规模验证。投入多少，最好有真实反馈可依。", action: "设计一个可回退的小尝试。"),
        .init(id: 40, name: "月满空庭", poem: "月满空庭静\n疏枝照影长\n心中容未定\n也自有清光", meaning: "暂时没有答案也可以。承认不知道，为了解留下空间。", action: "把一个尚未确定的问题标记为待核实。"),
        .init(id: 41, name: "竹篱护花", poem: "竹篱围小圃\n花影过墙来\n守得三分界\n才容自在开", meaning: "照顾关系不必牺牲全部边界。温和而明确地说明自己的需要。", action: "练习说一句清楚的拒绝。"),
        .init(id: 42, name: "潮平两岸", poem: "潮平连两岸\n行客各持舟\n相逢听一语\n未必问同流", meaning: "不同意见可以提供新信息。先理解对方的理由，再判断是否改变自己的选择。", action: "复述一条反对意见，并核实其中的事实。"),
        .init(id: 43, name: "春泥护根", poem: "春泥藏细雨\n新叶向光生\n未见繁花日\n根深亦有声", meaning: "准备常常发生在看不见的地方。把基础练习做好，也算推进。", action: "完成一项最基础的练习。"),
        .init(id: 44, name: "秋窗理线", poem: "秋窗理乱线\n一缕入针明\n莫急千般结\n先从近处清", meaning: "事情纠缠时，只处理眼前能够改变的一点。把大问题拆开，才能看见动作。", action: "选出五分钟内能开始的第一步。"),
        .init(id: 45, name: "渔火相望", poem: "渔火隔江远\n微明各一方\n愿将心上事\n说与可亲商", meaning: "支持不一定意味着替你解决问题。有人认真听见，也能让负担轻一些。", action: "向可信赖的人说明你现在需要倾听。"),
        .init(id: 46, name: "风过麦田", poem: "风过麦田缓\n金波入眼柔\n一分耕作后\n也许半分休", meaning: "努力与休息可以同时存在。持续投入需要身体和生活的余裕。", action: "在下一项任务前停留两分钟。"),
        .init(id: 47, name: "小院纳凉", poem: "小院纳凉夜\n星疏露渐生\n不争喧闹处\n独坐亦安宁", meaning: "独处不必等于疏离。尊重自己的社交精力，选择合适的连接方式。", action: "给不急的社交安排留一点弹性。"),
        .init(id: 48, name: "春笋问晴", poem: "春笋穿泥出\n檐前细雨收\n初行多未稳\n一步也温柔", meaning: "刚开始的不熟练并不意味着不适合。为试错留出有限而安全的空间。", action: "给新尝试设定一个可承受的试错预算。"),
        .init(id: 49, name: "古井照影", poem: "古井清光在\n浮尘拂可明\n问心无外物\n照见此时情", meaning: "外界的评价可以参考，自己的感受也值得辨认。先问清这件事对你意味着什么。", action: "写下不依赖别人认可的一个理由。"),
        .init(id: 50, name: "长堤看柳", poem: "长堤看柳色\n行缓亦逢春\n不为催舟客\n忘却自家门", meaning: "催促未必代表真正紧急。确认期限的来源，再安排自己的节奏。", action: "核实一个让你着急的期限。"),
        .init(id: 51, name: "雨帘听竹", poem: "雨帘垂竹外\n点滴各成音\n容得心头乱\n无须即刻晴", meaning: "情绪不必立刻被整理。允许它存在，再寻找当下能承受的一点照顾。", action: "给心情取一个名字，不作评判。"),
        .init(id: 52, name: "松窗留白", poem: "松窗留白纸\n淡墨写初山\n未必要填满\n空处亦心安", meaning: "计划不必塞满每个时段。留白能让意外和真实的需要有处安放。", action: "从日程里移走一项可选任务。"),
        .init(id: 53, name: "海棠初醒", poem: "海棠初醒雨\n花下有微香\n昨日容回顾\n今朝别有章", meaning: "过去可以提供经验，却不必决定全部未来。看看哪些条件已经不同。", action: "列出这次与上次不同的两个条件。"),
        .init(id: 54, name: "江月照篷", poem: "江月照孤篷\n归心有远灯\n未知先歇脚\n不必赶兼程", meaning: "未来不清楚时，先安排眼前的安全与休息。你可以在看清之后再继续。", action: "检查今晚最基本的生活安排。"),
        .init(id: 55, name: "芦花向水", poem: "芦花向水白\n轻絮不争高\n一念随风落\n心宽路自遥", meaning: "并非每个念头都需要跟着行动。先观察它是否在冷静后仍然重要。", action: "把一项临时冲动放到明天再看。"),
        .init(id: 56, name: "枫叶知秋", poem: "枫叶知秋意\n层林各有时\n人生多转折\n且把近枝持", meaning: "阶段改变时，需求也会改变。允许自己重新排序，而不是沿用所有旧目标。", action: "重新排列三项当下的优先级。"),
        .init(id: 57, name: "燕归旧檐", poem: "燕归寻旧垒\n新泥补雨痕\n若愿重修好\n先听两边心", meaning: "修复需要双方的意愿和具体行动。先看现实条件，再决定是否靠近。", action: "写清一段关系需要怎样的改变。"),
        .init(id: 58, name: "雪后寻梅", poem: "雪后寻梅影\n微香过短篱\n不催春尽到\n且惜一枝时", meaning: "一点改善已经值得被看见。不需要等到一切都好，才允许自己轻松一下。", action: "记录今天比昨天容易的一件事。"),
        .init(id: 59, name: "清风入袖", poem: "清风轻入袖\n远树落斜阳\n得失容商量\n身心各有方", meaning: "取舍不必只有全有或全无。看看是否存在更轻、更可回退的方式。", action: "为一个决定想出一个折中方案。"),
        .init(id: 60, name: "灯下补衣", poem: "灯下轻补衣\n针针有来由\n旧物容修整\n新日亦温柔", meaning: "补足一个小缺口，有时比彻底推翻更实际。先找出真正影响使用的部分。", action: "修补一个能解决的小问题。"),
        .init(id: 61, name: "雨润空山", poem: "雨润空山静\n溪流绕石行\n曲中能有路\n不必争直程", meaning: "绕一点路不等于失败。遇到阻碍时，可以改变方法而保留目标。", action: "为卡住的任务列出另一种做法。"),
        .init(id: 62, name: "榕荫歇脚", poem: "榕荫容过客\n长凳落晴光\n坐定听风缓\n归途未必忙", meaning: "给自己一个被支撑的片刻。放松身体后，再判断是否需要继续。", action: "找一个有支撑的位置坐一会儿。"),
        .init(id: 63, name: "晨星未远", poem: "晨星悬晓色\n窗外有鸡鸣\n未定千重路\n先行一小程", meaning: "不必把长期计划想透才开始。第一步只要具体、可承受、可检查。", action: "写下一个今天能够完成的动作。"),
        .init(id: 64, name: "荷风送远", poem: "荷风穿小榭\n清水见云移\n话到心平处\n从容说所期", meaning: "沟通不必一次说完所有问题。选择一件最重要的事，清楚表达期待。", action: "用一句话说明你最希望改变的事。"),
        .init(id: 65, name: "远钟入林", poem: "远钟穿密叶\n余响落青苔\n慢把心收拢\n纷纷暂不猜", meaning: "信息过多时，可以先减少输入。留出一点安静，分辨什么真正与你有关。", action: "关闭一项非必要的信息提醒。"),
        .init(id: 66, name: "溪石有纹", poem: "溪石藏年岁\n水痕各不同\n不须同一面\n方见万般容", meaning: "不同的经历会形成不同的选择。不要只凭他人的结果判断自己的道路。", action: "写下一项只有你自己清楚的现实条件。"),
        .init(id: 67, name: "柳絮轻落", poem: "柳絮轻轻落\n风来不问迟\n心头留片地\n容我慢相知", meaning: "认识自己需要反复观察。给答案留一点变化的余地。", action: "记录一个最近才发现的偏好。"),
        .init(id: 68, name: "松火温粥", poem: "松火温朝粥\n香烟绕短檐\n万般纷扰外\n先把此身安", meaning: "先满足基本需要，再处理复杂选择。饥饿和疲惫都可能让事情显得更急。", action: "先吃饭或休息，再回看眼前的问题。"),
        .init(id: 69, name: "星灯相伴", poem: "星灯分远近\n各自照来程\n若问何为伴\n能听一片心", meaning: "值得信赖的关系容得下真实感受。不必先把自己整理完美才寻求陪伴。", action: "向信任的人说一句真实的近况。"),
        .init(id: 70, name: "花径留步", poem: "花径留微步\n春深不计程\n偶回身后望\n原有几分青", meaning: "回顾不是停在过去，而是从经历中找到能继续使用的东西。", action: "记下一条这段经历教给你的方法。"),
        .init(id: 71, name: "河湾见岸", poem: "河湾转水缓\n远岸有炊烟\n此处容停靠\n前途再细看", meaning: "需要调整投入时，先确认可以停在哪里。退出条件能保护后续选择。", action: "写下何时暂停的一条明确标准。"),
        .init(id: 72, name: "竹露未晞", poem: "竹露清晨重\n风轻叶自舒\n心中多未解\n不碍读新书", meaning: "没有解决全部问题，也可以做一件具体的事。行动与不确定可以并存。", action: "在担心之外，完成一项独立的小任务。"),
        .init(id: 73, name: "秋灯共话", poem: "秋灯明小室\n茶暖话声低\n先听人所念\n再把己心题", meaning: "先理解对方最在意的部分，常能减少无谓争执。理解不等于必须同意。", action: "在回应前，先复述对方的一项需要。"),
        .init(id: 74, name: "山泉绕石", poem: "山泉能绕石\n细水自成行\n不借千钧力\n也留一线长", meaning: "持续的小投入可以积累信息。不必用一次很大的付出来证明认真。", action: "把一项任务缩小到可重复的规模。"),
        .init(id: 75, name: "纸鸢收线", poem: "纸鸢迎远日\n收线有轻重\n愿逐长风去\n仍知脚下踪", meaning: "愿望可以大胆，行动需要边界。想象之后，也核实脚下的支持。", action: "检查一个理想背后的现实成本。"),
        .init(id: 76, name: "晚晴归路", poem: "晚晴明归路\n步缓影相随\n不问今朝满\n先将所得知", meaning: "一天的价值不只由完成数量决定。留意做过的努力，也允许未完成。", action: "给今天留一句不苛刻的评价。"),
        .init(id: 77, name: "篱菊问香", poem: "篱菊开何处\n轻香不自夸\n若逢知己客\n同看一枝花", meaning: "分享不必为了证明自己。把一件真实的小喜悦，交给愿意听的人。", action: "分享一个具体而平常的好消息。"),
        .init(id: 78, name: "云间见岭", poem: "云间山渐见\n未尽路还长\n只问当前石\n能容一步安", meaning: "只看眼前可核实的部分，也足以支持一个小决定。远处可以等信息更多再判断。", action: "核实下一步最关键的一项条件。"),
        .init(id: 79, name: "溪边拾叶", poem: "溪边拾落叶\n纹理见秋深\n往事容轻放\n新篇亦可寻", meaning: "有些经验值得保留，有些负担可以放下。区分它们，不必否定整段经历。", action: "写下一项想保留的经验和一项可放下的要求。"),
        .init(id: 80, name: "春窗换水", poem: "春窗花影静\n换水见清明\n照顾从微处\n无须等大成", meaning: "照顾可以从很小的动作开始。不要因为它简单，就忽略它对日常的意义。", action: "完成一件两分钟的自我照顾。"),
        .init(id: 81, name: "竹桥同行", poem: "竹桥临细涧\n两岸有人声\n若共前途路\n先言各自行", meaning: "合作之前，把各自的责任和期待说清楚。共同目标也需要具体分工。", action: "确认一次合作中的下一步由谁完成。"),
        .init(id: 82, name: "庭前听雪", poem: "庭前听细雪\n灯下有余温\n静处容心事\n无须即刻论", meaning: "有时感受需要被陪伴，而不是被解释。你可以先不寻找结论。", action: "把一段心情写下，只描述不分析。"),
        .init(id: 83, name: "松风入梦", poem: "松风吹夜枕\n星影落檐间\n明日仍能问\n今宵且暂闲", meaning: "有些决定适合在休息之后再看。把问题记下来，让今晚先有结束。", action: "为明天写一条提醒，然后停止反复检查。"),
        .init(id: 84, name: "花影成双", poem: "花影随枝动\n清风各自来\n相知留分寸\n并坐也舒怀", meaning: "亲近可以保留各自的空间。留意你是否能表达喜欢，也能说出不同。", action: "向重要的人表达一个小需求。"),
        .init(id: 85, name: "山门问径", poem: "山门分石径\n远寺隔林青\n未识来回路\n先询过客行", meaning: "面对陌生选择，先了解真实日常。经验分享可以帮助你发现没有想到的成本。", action: "问一位亲历者：最难的日常是什么？"),
        .init(id: 86, name: "清露润叶", poem: "清露添新叶\n朝光未满庭\n不求枝尽绿\n先护一芽青", meaning: "把有限精力投入最重要的一点。不是所有任务都需要今天达到最好。", action: "挑一项任务做到足够好即可。"),
        .init(id: 87, name: "江风稳舵", poem: "江风来不定\n稳舵看潮平\n心动容保留\n行前问实情", meaning: "感觉可以提供方向，事实帮助决定投入。把两者分别写下，再一起看。", action: "列出两条事实和一条个人偏好。"),
        .init(id: 88, name: "枕书听雨", poem: "枕书听夜雨\n一页识新章\n不以迟为负\n重来亦有光", meaning: "回到基础不意味着退步。发现盲点后重新学习，本身就是调整能力。", action: "重做一个曾经没弄懂的小例子。"),
        .init(id: 89, name: "桂子无声", poem: "桂子落无声\n微香到远庭\n积微成日久\n不必急求名", meaning: "稳固的积累有时很安静。把注意力放在可重复的过程，而不是即时认可。", action: "设定一项不依赖赞赏的小练习。"),
        .init(id: 90, name: "舟回浅港", poem: "舟回寻浅港\n雨歇水纹轻\n卸得三分重\n方能再启程", meaning: "减少负担能为下一步留下力气。先看看有哪些承诺可以重新协商。", action: "把一项超出精力的安排说清楚。"),
        .init(id: 91, name: "云开小窗", poem: "云开明小窗\n远树入新晴\n未必要远去\n近处也能生", meaning: "变化不一定意味着彻底离开。试着在现有条件里找到一个可调整的部分。", action: "为现状提出一个成本较低的改变。"),
        .init(id: 92, name: "竹简留字", poem: "竹简留新字\n灯前细细看\n愿将心上愿\n写作可行单", meaning: "把目标写成动作，可以减少空转。越具体，越容易知道是否需要调整。", action: "为一个愿望写下时间和完成标准。"),
        .init(id: 93, name: "晨鸟启程", poem: "晨鸟辞庭树\n天空尚未明\n未知能作伴\n振翼有轻声", meaning: "开始时的不确定很正常。带着观察去尝试，不需要承诺一次成功。", action: "为新行动设一个反馈检查点。"),
        .init(id: 94, name: "细雨归田", poem: "细雨归田陌\n新泥护浅根\n辛勤容有界\n歇后再耕耘", meaning: "付出也需要合理边界。可持续的节奏比透支更适合长期安排。", action: "给今天的工作写一个停止时间。"),
        .init(id: 95, name: "远帆有岸", poem: "远帆依水阔\n岸影渐分明\n愿景容千里\n脚下有归程", meaning: "愿景之外，也确认回退方案。保留选择空间，能让行动更从容。", action: "列出一个主要方案和一个备用方案。"),
        .init(id: 96, name: "晚风拂衣", poem: "晚风轻拂衣\n街角一灯明\n经过纷纷处\n还听自己声", meaning: "热闹的建议未必适合你的条件。安静下来，分辨最想守住的东西。", action: "写下这次选择不可牺牲的一项需要。"),
        .init(id: 97, name: "水榭知音", poem: "水榭闻弦缓\n余音入夜深\n知音能共语\n不必尽同心", meaning: "好的交流不要求处处相同。把不同意见说具体，也给对方解释的空间。", action: "就一件事交换理由，而不评判彼此。"),
        .init(id: 98, name: "春山入画", poem: "春山添浅色\n淡墨亦成峰\n未尽丹青意\n留来日日工", meaning: "完成可以是逐步发生的。先做出一个粗略版本，再根据反馈改进。", action: "给自己一个可以不完美的第一稿。"),
        .init(id: 99, name: "灯照归人", poem: "灯照归人影\n门前饭尚温\n风尘容洗去\n此刻有安存", meaning: "不管今天走得怎样，都可以回到照顾自己的日常。结果不决定你是否值得被关心。", action: "完成一件让身体舒服一点的小事。"),
        .init(id: 100, name: "百川归心", poem: "百川归远海\n一念落微尘\n看尽千般路\n仍须问此心", meaning: "许多提示最终都要回到你的现实和选择。留下有帮助的部分，其余可以轻轻放下。", action: "合上签笺，用自己的话写出下一步。")
    ]
}

struct DrawRecord: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let emotion: DrawEmotion
    let lotID: Int
    var tradition: DrawMode? = nil
    var smallAction: SmallAction? = nil
    var actionCatalogVersion: Int? = nil
    var mode: DrawMode { tradition ?? .original }
    var guanyinLot: GuanyinLot? { mode == .guanyin ? GuanyinLot.all.first { $0.id == lotID } : nil }
    var name: String { guanyinLot?.title ?? lot.name }
    var poem: String { guanyinLot?.poem ?? lot.poem }
    var lot: CulturalLot { CulturalLot.all.first { $0.id == lotID } ?? CulturalLot.all[0] }
    var interpretation: String {
        if let guanyinLot { return guanyinLot.reflection(emotion: emotion) }
        return switch emotion {
        case .sad: "难过不需要被一支签解释，也不必马上变好。\(lot.meaning) 你值得被耐心对待，今天做到一点点就够了。"
        case .grieving: "无论你正在经历怎样的失落，都不必按别人的时间表恢复。\(lot.meaning) 可以请一个信任的人陪一会儿，先照顾好吃饭和休息。"
        case .excited: "此刻先把决定放慢一点。\(lot.meaning) 把支持和反对的事实分别列出，确认损失上限，再决定是否行动。热情可以保留，判断留给平稳的自己。"
        case .happy: "把今天的好心情收好。\(lot.meaning) 可以分享喜悦，也给接下来的行动留一个踏实的小步骤。"
        case .neutral: lot.meaning
        }
    }
    var nextStep: String {
        if let smallAction { return smallAction.text }
        if actionCatalogVersion != nil { return "适合此刻情绪的小事已读完，已用内容不会重复推送。" }
        return lot.action
    }
    var shareText: String { "值得吗？ · \(mode.title) · 第\(lotID)签「\(name)」\n\(poem)\n\n\(interpretation)\n\(mode == .original ? "原创签诗" : "观音灵签七言通行版")，供文化阅读与自我关照，不预测吉凶。" }
}

@Observable final class LotteryStore {
    private(set) var records: [DrawRecord] = []
    private let defaults: UserDefaults
    private let key: String
    private let actionKey: String
    private var used: Set<String>
    init(profileID: UUID, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = Self.key(profileID)
        actionKey = Self.actionKey(profileID)
        used = Set(defaults.stringArray(forKey: actionKey) ?? [])
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode([DrawRecord].self, from: data) { records = saved }
        used.formUnion(records.compactMap { $0.smallAction?.id })
        // Upgrade old records once; history keeps its assigned action on every later opening.
        for index in records.indices.reversed() where records[index].actionCatalogVersion == nil {
            records[index].smallAction = takeAction(emotion: records[index].emotion)
            records[index].actionCatalogVersion = 1
        }
        persist()
    }
    private func takeAction(emotion: DrawEmotion) -> SmallAction? {
        guard let action = SmallAction.all.filter({ $0.emotions.contains(emotion) && !used.contains($0.id) }).randomElement() else { return nil }
        used.insert(action.id)
        return action
    }
    @discardableResult func draw(emotion: DrawEmotion, mode: DrawMode = .original, now: Date = .now) -> DrawRecord {
        var record = DrawRecord(date: now, emotion: emotion, lotID: Int.random(in: 1...100), tradition: mode)
        record.smallAction = takeAction(emotion: emotion)
        record.actionCatalogVersion = 1
        records.insert(record, at: 0)
        records = Array(records.prefix(100))
        persist()
        return record
    }
    private func persist() {
        defaults.set(Array(used).sorted(), forKey: actionKey)
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: key) }
    }
    static func key(_ id: UUID) -> String { "worthit.lots.v1.\(id.uuidString)" }
    static func actionKey(_ id: UUID) -> String { "worthit.lot-actions.v1.\(id.uuidString)" }
}
