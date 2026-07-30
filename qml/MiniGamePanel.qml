import QtQuick
import QtQuick.Layouts

Item {
    id: root
    signal closed()
    focus: true

    readonly property string _fontFamily: "Noto Serif CJK JP"

    property string gameState: "menu"
    property var questions: []
    property int currentQuestion: 0
    property int score: 0
    property int totalQuestions: 10
    property int selectedAnswer: -1
    property bool answerRevealed: false
    property string kurisuEmotion: "NORMAL"
    property real miniSpeak: 0.0
    property bool speaking: false

    function t(key, defaultValue) {
        var trans = Localization.translations;
        if (trans && trans[key] !== undefined) return trans[key];
        return defaultValue || key;
    }

    function tt(pair) { return t(pair[0], pair[1]); }

    function shuffleArray(arr) {
        for (var i = arr.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
        }
        return arr;
    }

    function generateQuestions() {
        var pool = [
            { q: ["mgq_drink_q", "紅莉栖の好きな飲み物は？"], a: [["mgq_drink_a0", "Dr. Pepper"], ["mgq_drink_a1", "コーラ"], ["mgq_drink_a2", "コーヒー"], ["mgq_drink_a3", "紅茶"]], correct: 0, c: ["mgq_drink_c", "べ、別に好きってわけじゃないんだから！"] },
            { q: ["mgq_fg8_q", "未来ガジェット8号機の名前は？"], a: [["mgq_fg8_a0", "電話レンジ（仮）"], ["mgq_fg8_a1", "ビット粒子砲"], ["mgq_fg8_a2", "サイリウム・セーバー"], ["mgq_fg8_a3", "モアッド・スネーク"]], correct: 0, c: ["mgq_fg8_c", "電話レンジ（仮）。命名センスは問わないで。"] },
            { q: ["mgq_fg1_q", "未来ガジェット1号機の名前は？"], a: [["mgq_fg1_a0", "ビット粒子砲"], ["mgq_fg1_a1", "タケコプカメラー"], ["mgq_fg1_a2", "サイリウム・セーバー"], ["mgq_fg1_a3", "攻殻機動迷彩ボール"]], correct: 0, c: ["mgq_fg1_c", "ビット粒子砲。光るだけだけどね。"] },
            { q: ["mgq_bday_kurisu_q", "牧瀬紅莉栖の誕生日は？"], a: [["mgq_bday_kurisu_a0", "7月25日"], ["mgq_bday_kurisu_a1", "7月28日"], ["mgq_bday_kurisu_a2", "12月14日"], ["mgq_bday_kurisu_a3", "2月1日"]], correct: 0, c: ["mgq_bday_kurisu_c", "7月25日。…なんで知ってるの？"] },
            { q: ["mgq_bday_okabe_q", "岡部倫太郎の誕生日は？"], a: [["mgq_bday_okabe_a0", "12月14日"], ["mgq_bday_okabe_a1", "7月25日"], ["mgq_bday_okabe_a2", "5月19日"], ["mgq_bday_okabe_a3", "9月27日"]], correct: 0, c: ["mgq_bday_okabe_c", "12月14日。鳳凰院凶真の誕生日でもあるわ。"] },
            { q: ["mgq_bday_mayuri_q", "椎名まゆりの誕生日は？"], a: [["mgq_bday_mayuri_a0", "2月1日"], ["mgq_bday_mayuri_a1", "7月7日"], ["mgq_bday_mayuri_a2", "11月9日"], ["mgq_bday_mayuri_a3", "4月3日"]], correct: 0, c: ["mgq_bday_mayuri_c", "2月1日。絶対に忘れちゃダメなんだから。"] },
            { q: ["mgq_meter_q", "世界線の変動率を測る装置の名前は？"], a: [["mgq_meter_a0", "ダイバージェンスメーター"], ["mgq_meter_a1", "リーディングシュタイナー"], ["mgq_meter_a2", "タイムリープマシン"], ["mgq_meter_a3", "電話レンジ（仮）"]], correct: 0, c: ["mgq_meter_c", "ダイバージェンスメーター。岡部が作ったのよ。"] },
            { q: ["mgq_hououin_q", "岡部倫太郎のもう一つの名は？"], a: [["mgq_hououin_a0", "鳳凰院凶真"], ["mgq_hououin_a1", "クリスティーナ"], ["mgq_hououin_a2", "助手"], ["mgq_hououin_a3", "The Zombie"]], correct: 0, c: ["mgq_hououin_c", "鳳凰院凶真。…中二病だけど。"] },
            { q: ["mgq_sg_div_q", "「シュタインズ・ゲート」世界線の変動率は？"], a: [["mgq_sg_div_a0", "1.048596%"], ["mgq_sg_div_a1", "0.571024%"], ["mgq_sg_div_a2", "1.130426%"], ["mgq_sg_div_a3", "1.064756%"]], correct: 0, c: ["mgq_sg_div_c", "1.048596%。当然知ってるわよね？"] },
            { q: ["mgq_handle_q", "紅莉栖の＠ちゃんねるハンドルネームは？"], a: [["mgq_handle_a0", "栗悟飯とカメハメ波"], ["mgq_handle_a1", "クリスティーナ"], ["mgq_handle_a2", "助手"], ["mgq_handle_a3", "The Zombie"]], correct: 0, c: ["mgq_handle_c", "栗悟飯とカメハメ波よ。…って、あんた＠ちゃんねる見てるんじゃないでしょうね？！"] },
            { q: ["mgq_univ_q", "紅莉栖が在籍していた大学は？"], a: [["mgq_univ_a0", "ヴィクトル・コンドリア大学"], ["mgq_univ_a1", "東京大学"], ["mgq_univ_a2", "MIT"], ["mgq_univ_a3", "ケンブリッジ大学"]], correct: 0, c: ["mgq_univ_c", "ヴィクトル・コンドリア大学。脳科学の研究よ。"] },
            { q: ["mgq_lab_q", "秋葉原にあるラボの名前は？"], a: [["mgq_lab_a0", "未来ガジェット研究所"], ["mgq_lab_a1", "SERN"], ["mgq_lab_a2", "円卓会議"], ["mgq_lab_a3", "ブラウン管工房"]], correct: 0, c: ["mgq_lab_c", "未来ガジェット研究所。オンボロビルの2階よ。"] },
            { q: ["mgq_timeleap_q", "記憶を過去に送る機械の名前は？"], a: [["mgq_timeleap_a0", "タイムリープマシン"], ["mgq_timeleap_a1", "タイムマシン"], ["mgq_timeleap_a2", "Dメール"], ["mgq_timeleap_a3", "ダイバージェンスメーター"]], correct: 0, c: ["mgq_timeleap_c", "タイムリープマシン。記憶を36バイトに圧縮するの。"] },
            { q: ["mgq_labmem_q", "紅莉栖のラボメンナンバーは？"], a: [["mgq_labmem_a0", "004"], ["mgq_labmem_a1", "001"], ["mgq_labmem_a2", "003"], ["mgq_labmem_a3", "008"]], correct: 0, c: ["mgq_labmem_c", "004。私よ。何か文句ある？"] },
            { q: ["mgq_bday_daru_q", "橋田至（ダル）の誕生日は？"], a: [["mgq_bday_daru_a0", "5月19日"], ["mgq_bday_daru_a1", "6月6日"], ["mgq_bday_daru_a2", "8月30日"], ["mgq_bday_daru_a3", "9月27日"]], correct: 0, c: ["mgq_bday_daru_c", "5月19日。スーパーハカーの誕生日よ。"] },
            { q: ["mgq_bday_moeka_q", "桐生萌郁の誕生日は？"], a: [["mgq_bday_moeka_a0", "6月6日"], ["mgq_bday_moeka_a1", "5月19日"], ["mgq_bday_moeka_a2", "8月30日"], ["mgq_bday_moeka_a3", "11月9日"]], correct: 0, c: ["mgq_bday_moeka_c", "6月6日。シャイニング・フィンガーね。"] },
            { q: ["mgq_bday_ruka_q", "漆原るかの誕生日は？"], a: [["mgq_bday_ruka_a0", "8月30日"], ["mgq_bday_ruka_a1", "9月27日"], ["mgq_bday_ruka_a2", "7月7日"], ["mgq_bday_ruka_a3", "4月3日"]], correct: 0, c: ["mgq_bday_ruka_c", "8月30日。性別を間違えちゃダメよ。"] },
            { q: ["mgq_bday_suzuha_q", "阿万音鈴羽の誕生日は？"], a: [["mgq_bday_suzuha_a0", "9月27日"], ["mgq_bday_suzuha_a1", "8月30日"], ["mgq_bday_suzuha_a2", "5月31日"], ["mgq_bday_suzuha_a3", "11月2日"]], correct: 0, c: ["mgq_bday_suzuha_c", "9月27日。バイト戦士の誕生日よ。"] },
            { q: ["mgq_bday_faris_q", "フェイリス・ニャンニアンの誕生日は？"], a: [["mgq_bday_faris_a0", "4月3日"], ["mgq_bday_faris_a1", "2月1日"], ["mgq_bday_faris_a2", "7月7日"], ["mgq_bday_faris_a3", "11月9日"]], correct: 0, c: ["mgq_bday_faris_c", "4月3日。ニャニャン…私はやらないわよ。"] },
            { q: ["mgq_bday_nae_q", "天王寺綯の誕生日は？"], a: [["mgq_bday_nae_a0", "11月9日"], ["mgq_bday_nae_a1", "11月2日"], ["mgq_bday_nae_a2", "7月7日"], ["mgq_bday_nae_a3", "12月14日"]], correct: 0, c: ["mgq_bday_nae_c", "11月9日。いじめちゃダメよ。"] },
            { q: ["mgq_bday_maho_q", "比屋定真帆の誕生日は？"], a: [["mgq_bday_maho_a0", "11月2日"], ["mgq_bday_maho_a1", "11月9日"], ["mgq_bday_maho_a2", "8月23日"], ["mgq_bday_maho_a3", "6月13日"]], correct: 0, c: ["mgq_bday_maho_c", "11月2日。私の同僚…みたいなものよ。"] },
            { q: ["mgq_fg2_q", "未来ガジェット2号機の名前は？"], a: [["mgq_fg2_a0", "タケコプカメラー"], ["mgq_fg2_a1", "ビット粒子砲"], ["mgq_fg2_a2", "サイリウム・セーバー"], ["mgq_fg2_a3", "モアッド・スネーク"]], correct: 0, c: ["mgq_fg2_c", "タケコプカメラー。飛べないけどね。"] },
            { q: ["mgq_fg3_q", "未来ガジェット3号機の名前は？"], a: [["mgq_fg3_a0", "もしかしてオラオラですかーっ!?"], ["mgq_fg3_a1", "モアッド・スネーク"], ["mgq_fg3_a2", "バーローのアレ"], ["mgq_fg3_a3", "びっくりメガネちゃん"]], correct: 0, c: ["mgq_fg3_c", "「もしかしてオラオラですかーっ!?」…どういう名前よ。"] },
            { q: ["mgq_fg4_q", "未来ガジェット4号機の名前は？"], a: [["mgq_fg4_a0", "モアッド・スネーク"], ["mgq_fg4_a1", "ビット粒子砲"], ["mgq_fg4_a2", "攻殻機動迷彩ボール"], ["mgq_fg4_a3", "ホーミング・ディーヴァ"]], correct: 0, c: ["mgq_fg4_c", "モアッド・スネーク。ただのヘビよ。"] },
            { q: ["mgq_fg5_q", "未来ガジェット5号機の名前は？"], a: [["mgq_fg5_a0", "またつまらぬものを繋げてしまった"], ["mgq_fg5_a1", "タケコプカメラー"], ["mgq_fg5_a2", "サイリウム・セーバー"], ["mgq_fg5_a3", "ダーリンのばかぁ"]], correct: 0, c: ["mgq_fg5_c", "「またつまらぬものを繋げてしまった」…長いわよ。"] },
            { q: ["mgq_fg6_q", "未来ガジェット6号機の名前は？"], a: [["mgq_fg6_a0", "サイリウム・セーバー"], ["mgq_fg6_a1", "ビット粒子砲"], ["mgq_fg6_a2", "攻殻機動迷彩ボール"], ["mgq_fg6_a3", "電話レンジ（仮）"]], correct: 0, c: ["mgq_fg6_c", "サイリウム・セーバー。“改”もあるわよ。"] },
            { q: ["mgq_fg7_q", "未来ガジェット7号機の名前は？"], a: [["mgq_fg7_a0", "攻殻機動迷彩ボール"], ["mgq_fg7_a1", "サイリウム・セーバー"], ["mgq_fg7_a2", "モアッド・スネーク"], ["mgq_fg7_a3", "びっくりメガネちゃん"]], correct: 0, c: ["mgq_fg7_c", "攻殻機動迷彩ボール。要するに透明化ね。"] },
            { q: ["mgq_fg9_q", "未来ガジェット9号機の名前は？"], a: [["mgq_fg9_a0", "帰還の女神（ホーミング・ディーヴァ）"], ["mgq_fg9_a1", "びっくりメガネちゃん"], ["mgq_fg9_a2", "バーローのアレ"], ["mgq_fg9_a3", "ダーリンのばかぁ"]], correct: 0, c: ["mgq_fg9_c", "泣き濡れし女神の帰還 ホーミング・ディーヴァよ。"] },
            { q: ["mgq_fg10_q", "未来ガジェット10号機の名前は？"], a: [["mgq_fg10_a0", "びっくりメガネちゃん"], ["mgq_fg10_a1", "バーローのアレ"], ["mgq_fg10_a2", "ホーミング・ディーヴァ"], ["mgq_fg10_a3", "モアッド・スネーク"]], correct: 0, c: ["mgq_fg10_c", "びっくりメガネちゃん。ただのメガネよ。"] },
            { q: ["mgq_div_alpha_q", "α世界線（本編開始）のダイバージェンスは？"], a: [["mgq_div_alpha_a0", "0.571024%"], ["mgq_div_alpha_a1", "1.048596%"], ["mgq_div_alpha_a2", "1.130426%"], ["mgq_div_alpha_a3", "-0.275349%"]], correct: 0, c: ["mgq_div_alpha_c", "0.571024%。まゆりが…なんでもないわ。"] },
            { q: ["mgq_div_omega_q", "フェイリスENDのΩ世界線の変動率は？"], a: [["mgq_div_omega_a0", "-0.275349%"], ["mgq_div_omega_a1", "0.000000%"], ["mgq_div_omega_a2", "0.456903%"], ["mgq_div_omega_a3", "0.571024%"]], correct: 0, c: ["mgq_div_omega_c", "-0.275349%。負の値、フェイリスの世界線よ。"] },
            { q: ["mgq_op_skuld_q", "ゼロで紅莉栖を救う作戦の名前は？"], a: [["mgq_op_skuld_a0", "オペレーション・スクルド"], ["mgq_op_skuld_a1", "オペレーション・ウルド"], ["mgq_op_skuld_a2", "オペレーション・アークライト"], ["mgq_op_skuld_a3", "オペレーション・アマテラス"]], correct: 0, c: ["mgq_op_skuld_c", "オペレーション・スクルド。運命の三姉妹の名よ。"] },
            { q: ["mgq_op_urd_q", "次のうち、作中に登場するオペレーション名は？"], a: [["mgq_op_urd_a0", "オペレーション・ウルド"], ["mgq_op_urd_a1", "オペレーション・オーディン"], ["mgq_op_urd_a2", "オペレーション・トール"], ["mgq_op_urd_a3", "オペレーション・ロキ"]], correct: 0, c: ["mgq_op_urd_c", "オペレーション・ウルド。これも三姉妹の名よ。"] },
            { q: ["mgq_labmem_okabe_q", "岡部のラボメンナンバーは？"], a: [["mgq_labmem_okabe_a0", "001"], ["mgq_labmem_okabe_a1", "002"], ["mgq_labmem_okabe_a2", "003"], ["mgq_labmem_okabe_a3", "008"]], correct: 0, c: ["mgq_labmem_okabe_c", "001。創設者よ。鳳凰院凶真だけど。"] },
            { q: ["mgq_labmem_mayuri_q", "まゆりのラボメンナンバーは？"], a: [["mgq_labmem_mayuri_a0", "002"], ["mgq_labmem_mayuri_a1", "001"], ["mgq_labmem_mayuri_a2", "004"], ["mgq_labmem_mayuri_a3", "006"]], correct: 0, c: ["mgq_labmem_mayuri_c", "002。まゆりの番号よ。"] },
            { q: ["mgq_labmem_daru_q", "ダルのラボメンナンバーは？"], a: [["mgq_labmem_daru_a0", "003"], ["mgq_labmem_daru_a1", "004"], ["mgq_labmem_daru_a2", "005"], ["mgq_labmem_daru_a3", "007"]], correct: 0, c: ["mgq_labmem_daru_c", "003。スーパーハカーね。"] },
            { q: ["mgq_labmem_suzuha_q", "鈴羽のラボメンナンバーは？"], a: [["mgq_labmem_suzuha_a0", "008"], ["mgq_labmem_suzuha_a1", "006"], ["mgq_labmem_suzuha_a2", "007"], ["mgq_labmem_suzuha_a3", "005"]], correct: 0, c: ["mgq_labmem_suzuha_c", "008。最後のラボメンよ。"] },
            { q: ["mgq_blood_kurisu_q", "紅莉栖の血液型は？"], a: [["mgq_blood_kurisu_a0", "A型"], ["mgq_blood_kurisu_a1", "B型"], ["mgq_blood_kurisu_a2", "O型"], ["mgq_blood_kurisu_a3", "AB型"]], correct: 0, c: ["mgq_blood_kurisu_c", "A型。何か聞きたいことでも？"] },
            { q: ["mgq_height_kurisu_q", "紅莉栖の身長は？"], a: [["mgq_height_kurisu_a0", "160cm"], ["mgq_height_kurisu_a1", "155cm"], ["mgq_height_kurisu_a2", "165cm"], ["mgq_height_kurisu_a3", "170cm"]], correct: 0, c: ["mgq_height_kurisu_c", "160cm。小さいとか言わないでよ！"] },
            { q: ["mgq_birthstone_kurisu_q", "紅莉栖の誕生石は？"], a: [["mgq_birthstone_kurisu_a0", "ルビー"], ["mgq_birthstone_kurisu_a1", "ターコイズ"], ["mgq_birthstone_kurisu_a2", "パール"], ["mgq_birthstone_kurisu_a3", "ダイヤモンド"]], correct: 0, c: ["mgq_birthstone_kurisu_c", "ルビー。7月の誕生石よ。"] },
            { q: ["mgq_zodiac_kurisu_q", "紅莉栖の星座は？"], a: [["mgq_zodiac_kurisu_a0", "獅子座"], ["mgq_zodiac_kurisu_a1", "射手座"], ["mgq_zodiac_kurisu_a2", "水瓶座"], ["mgq_zodiac_kurisu_a3", "魚座"]], correct: 0, c: ["mgq_zodiac_kurisu_c", "獅子座。何か意外？"] },
            { q: ["mgq_height_okabe_q", "岡部の身長は？"], a: [["mgq_height_okabe_a0", "177cm"], ["mgq_height_okabe_a1", "170cm"], ["mgq_height_okabe_a2", "180cm"], ["mgq_height_okabe_a3", "165cm"]], correct: 0, c: ["mgq_height_okabe_c", "177cm。あいつ、高いのよね。"] },
            { q: ["mgq_timeleap_bytes_q", "タイムリープマシンで記憶を送れるのは何バイト？"], a: [["mgq_timeleap_bytes_a0", "36バイト"], ["mgq_timeleap_bytes_a1", "128バイト"], ["mgq_timeleap_bytes_a2", "1KB"], ["mgq_timeleap_bytes_a3", "512バイト"]], correct: 0, c: ["mgq_timeleap_bytes_c", "36バイト。記憶を圧縮するのよ。"] },
            { q: ["mgq_ibn5100_q", "IBN5100の元ネタとなったPCは？"], a: [["mgq_ibn5100_a0", "IBM5100"], ["mgq_ibn5100_a1", "Apple II"], ["mgq_ibn5100_a2", "PC-9801"], ["mgq_ibn5100_a3", "MSX"]], correct: 0, c: ["mgq_ibn5100_c", "IBM5100。伝説のPCよ。"] },
            { q: ["mgq_reading_steiner_q", "世界線移動後も記憶を保つ能力の名前は？"], a: [["mgq_reading_steiner_a0", "リーディングシュタイナー"], ["mgq_reading_steiner_a1", "ダイバージェンスメーター"], ["mgq_reading_steiner_a2", "タイムリープ"], ["mgq_reading_steiner_a3", "アマデウス"]], correct: 0, c: ["mgq_reading_steiner_c", "リーディングシュタイナー。岡部の…能力よ。"] },
            { q: ["mgq_amadeus_q", "人間の記憶を保存するAI研究システムの名前は？"], a: [["mgq_amadeus_a0", "アマデウス"], ["mgq_amadeus_a1", "SERN"], ["mgq_amadeus_a2", "円卓会議"], ["mgq_amadeus_a3", "ジョン・タイター"]], correct: 0, c: ["mgq_amadeus_c", "アマデウス。それは…私よ。"] },
            { q: ["mgq_lab_floor_q", "未来ガジェット研究所は何階にある？"], a: [["mgq_lab_floor_a0", "2階"], ["mgq_lab_floor_a1", "1階"], ["mgq_lab_floor_a2", "3階"], ["mgq_lab_floor_a3", "地下1階"]], correct: 0, c: ["mgq_lab_floor_c", "2階。ブラウン管工房の上よ。"] },
            { q: ["mgq_dmail_q", "過去へ送るメールの呼び名は？"], a: [["mgq_dmail_a0", "Dメール"], ["mgq_dmail_a1", "Eメール"], ["mgq_dmail_a2", "タイムメール"], ["mgq_dmail_a3", "Mメール"]], correct: 0, c: ["mgq_dmail_c", "Dメール。過去へのメールよ。"] },
            { q: ["mgq_mayuri_catchphrase_q", "まゆりの定番の挨拶は？"], a: [["mgq_mayuri_catchphrase_a0", "トゥットゥルー"], ["mgq_mayuri_catchphrase_a1", "ニャニャン"], ["mgq_mayuri_catchphrase_a2", "エル・プサイ・コングルゥ"], ["mgq_mayuri_catchphrase_a3", "いらっしゃい"]], correct: 0, c: ["mgq_mayuri_catchphrase_c", "トゥットゥルー。うつるから使わないで。"] },
        ];

        var indices = [];
        for (var i = 0; i < pool.length; i++) indices.push(i);
        shuffleArray(indices);

        var shuffled = [];
        for (var i = 0; i < totalQuestions && i < indices.length; i++) {
            var src = pool[indices[i]];
            var order = [];
            for (var k = 0; k < src.a.length; k++) order.push(k);
            shuffleArray(order);
            var newA = [];
            var newCorrect = 0;
            for (var k = 0; k < order.length; k++) {
                newA.push(src.a[order[k]]);
                if (order[k] === src.correct) newCorrect = k;
            }
            shuffled.push({ q: src.q, a: newA, correct: newCorrect, c: src.c });
        }
        return shuffled;
    }

    function resultEmotion() {
        if (score === totalQuestions) return "SMUG";
        if (score >= 6) return "SMILE";
        if (score >= 1) return "NORMAL";
        return "DISGUST";
    }

    function resultComment() {
        if (score === totalQuestions) return t("mg_result_perfect", "「パーフェクト！…まあ、当然の結果よね。」");
        if (score >= 6) return t("mg_result_good", "「ふーん、まあまあね。悪くないわ。」");
        if (score >= 1) return t("mg_result_ok", "「…もう少し勉強した方がいいんじゃない？」");
        return t("mg_result_bad", "「はぁ…全滅？本当にシュタゲ好きなの？」");
    }

    function currentComment() {
        if (!answerRevealed || questions.length <= currentQuestion) return "";
        var q = questions[currentQuestion];
        if (selectedAnswer === q.correct) return tt(q.c);
        return t("mg_wrong", "はぁ…不正解よ。答えは「%1」だったわ。").arg(tt(q.a[q.correct]));
    }

    function startGame() {
        stopSpeaking();
        questions = generateQuestions();
        currentQuestion = 0;
        score = 0;
        selectedAnswer = -1;
        answerRevealed = false;
        gameState = "playing";
        kurisuEmotion = "THINKING";
        if (typeof AchievementManager !== "undefined" && AchievementManager) {
            AchievementManager.notifyEvent("game_play");
        }
    }

    function selectAnswer(idx) {
        if (answerRevealed) return;
        selectedAnswer = idx;
        answerRevealed = true;
        var q = questions[currentQuestion];
        if (idx === q.correct) {
            score++;
            kurisuEmotion = "SMILE";
        } else {
            kurisuEmotion = "ANGRY";
        }
        startSpeaking(currentComment());
    }

    function nextQuestion() {
        stopSpeaking();
        currentQuestion++;
        selectedAnswer = -1;
        answerRevealed = false;
        if (currentQuestion >= questions.length) {
            gameState = "result";
            kurisuEmotion = resultEmotion();
            if (typeof AchievementManager !== "undefined" && AchievementManager) {
                if (score > 0) AchievementManager.notifyEvent("game_win");
                if (score === totalQuestions) AchievementManager.notifyEvent("game_perfect");
            }
        } else {
            kurisuEmotion = "THINKING";
        }
    }

    function startSpeaking(text) {
        var ms = Math.max(800, Math.min(3000, (text ? text.length : 0) * 90));
        speakStopTimer.interval = ms;
        root.miniSpeak = Math.random();
        root.speaking = true;
        speakStopTimer.restart();
    }

    function stopSpeaking() {
        root.speaking = false;
        root.miniSpeak = 0.0;
    }

    Timer {
        id: speakTimer
        interval: 120
        repeat: true
        running: root.speaking
        onTriggered: root.miniSpeak = Math.random()
    }

    Timer {
        id: speakStopTimer
        repeat: false
        onTriggered: root.stopSpeaking()
    }

    Text {
        anchors { top: parent.top; left: parent.left; topMargin: 40; leftMargin: 40 }
        text: "MINI GAME"
        color: "#FF9900"
        font { family: "MS Mincho"; pixelSize: 64 }
        z: 3
    }

    Item {
        anchors { top: parent.top; topMargin: 140; left: parent.left; leftMargin: 60; bottom: parent.bottom; bottomMargin: 80 }
        width: parent.width * 0.50
        z: 3

        ColumnLayout {
            anchors.fill: parent
            spacing: 30
            visible: root.gameState === "menu"

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: t("mg_menu_title", "紅莉栖とシュタゲクイズ")
                color: "#FFFFFF"
                font { family: root._fontFamily; pixelSize: 44 }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                text: t("mg_menu_desc", "シュタインズ・ゲートから%1問出題！").arg(root.totalQuestions)
                color: "#AAAAAA"
                font { family: root._fontFamily; pixelSize: 26 }
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 300; height: 70
                color: "#FF9900"
                Text {
                    anchors.centerIn: parent
                    text: t("mg_start", "スタート")
                    color: "#FFFFFF"
                    font { family: root._fontFamily; pixelSize: 32 }
                }
                MouseArea { anchors.fill: parent; onClicked: root.startGame() }
            }

            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 20
            visible: root.gameState === "playing"

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Q" + (root.currentQuestion + 1) + " / " + root.totalQuestions
                    color: "#FF9900"
                    font { family: root._fontFamily; pixelSize: 28 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: t("mg_score", "スコア") + ": " + root.score
                    color: "#FFFFFF"
                    font { family: root._fontFamily; pixelSize: 28 }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                color: "#1A1A1A"
                border.color: "#333333"
                Text {
                    anchors { fill: parent; margins: 20 }
                    text: root.questions.length > root.currentQuestion ? tt(root.questions[root.currentQuestion].q) : ""
                    color: "#FFFFFF"
                    font { family: root._fontFamily; pixelSize: 30 }
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 15
                columnSpacing: 15

                Repeater {
                    model: root.questions.length > root.currentQuestion ? root.questions[root.currentQuestion].a : []
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 65
                        color: {
                            if (!root.answerRevealed) return "#2A2A2A";
                            if (index === root.questions[root.currentQuestion].correct) return "#004400";
                            if (index === root.selectedAnswer) return "#440000";
                            return "#2A2A2A";
                        }
                        border.color: {
                            if (root.selectedAnswer === index && !root.answerRevealed) return "#FF9900";
                            return "#444444";
                        }
                        border.width: 1
                        Text {
                            anchors { fill: parent; margins: 15 }
                            text: tt(modelData)
                            color: "#FFFFFF"
                            font { family: root._fontFamily; pixelSize: 24 }
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.answerRevealed
                            onClicked: root.selectAnswer(index)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                visible: root.answerRevealed
                Layout.alignment: Qt.AlignRight
                width: 200; height: 55
                color: "#FF9900"
                Text {
                    anchors.centerIn: parent
                    text: root.currentQuestion + 1 >= root.totalQuestions ? t("mg_show_result", "結果を見る") : t("mg_next", "次の問題")
                    color: "#FFFFFF"
                    font { family: root._fontFamily; pixelSize: 26 }
                }
                MouseArea { anchors.fill: parent; onClicked: root.nextQuestion() }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 30
            visible: root.gameState === "result"

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: t("mg_result_title", "結果")
                color: "#FF9900"
                font { family: root._fontFamily; pixelSize: 48 }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: t("mg_score_result", "%1 / %2 正解").arg(root.score).arg(root.totalQuestions)
                color: "#FFFFFF"
                font { family: root._fontFamily; pixelSize: 40 }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                text: root.resultComment()
                color: "#FF9900"
                font { family: root._fontFamily; pixelSize: 26; italic: true }
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 30
                Rectangle {
                    width: 220; height: 60
                    color: "#FF9900"
                    Text { anchors.centerIn: parent; text: t("mg_retry", "もう一度"); color: "#FFF"; font { family: root._fontFamily; pixelSize: 28 } }
                    MouseArea { anchors.fill: parent; onClicked: root.startGame() }
                }
                Rectangle {
                    width: 220; height: 60
                    color: "#4D4D4D"
                    Text { anchors.centerIn: parent; text: t("mg_menu_back", "メニューへ"); color: "#FFF"; font { family: root._fontFamily; pixelSize: 28 } }
                    MouseArea { anchors.fill: parent; onClicked: { root.gameState = "menu"; root.kurisuEmotion = "SMILE"; } }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ─── Kurisu speech bubble ───
    Rectangle {
        id: commentBubble
        visible: root.answerRevealed && root.currentComment() !== ""
        anchors { right: parent.right; rightMargin: 120; bottom: parent.bottom; bottomMargin: 180 }
        width: 600
        height: commentText.implicitHeight + 40
        radius: 12
        color: "#E62D0F00"
        border.color: "#FF9900"
        border.width: 1
        z: 3
        Text {
            id: commentText
            anchors { fill: parent; margins: 20 }
            text: root.currentComment()
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 26 }
            wrapMode: Text.WordWrap
        }
    }

    // ─── Close Button (same size/position as other panels) ───
    Rectangle {
        width: 210; height: 70
        color: "#464646"
        anchors { right: parent.right; rightMargin: 100; bottom: parent.bottom; bottomMargin: 60 }
        z: 4
        Text {
            anchors.centerIn: parent
            text: t("close", "閉じる")
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 32 }
        }
        MouseArea { anchors.fill: parent; onClicked: root.closed() }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) {
            root.closed(); event.accepted = true;
        }
    }

    opacity: 0
    onVisibleChanged: {
        if (visible) {
            root.opacity = 0;
            Qt.callLater(function(){ root.opacity = 1; });
            if (root.gameState === "playing") root.kurisuEmotion = "THINKING";
            else if (root.gameState === "result") root.kurisuEmotion = resultEmotion();
            else root.kurisuEmotion = "SMILE";
        } else {
            root.stopSpeaking();
        }
    }
    Behavior on opacity { NumberAnimation { duration: 250 } }
    onClosed: { root.opacity = 0; closeTimer.start(); }
    Timer { id: closeTimer; interval: 250; onTriggered: root.visible = false }
}
