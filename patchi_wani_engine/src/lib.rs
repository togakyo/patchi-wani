//! patchi_wani_engine — Rust ゲームエンジン
//!
//! Flutter (dart:ffi) から C ABI 経由で呼び出される。
//! すべての public 関数は `extern "C" #[no_mangle]` で公開する。

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_float, c_int};
use std::sync::Mutex;

use serde::{Deserialize, Serialize};

// ─────────────────────────────────────────────
//  GameRule — Scratch ブロックが生成する設定 JSON
// ─────────────────────────────────────────────
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameRule {
    /// ゲーム制限時間（秒）
    pub duration_secs: u32,
    /// ターゲット表示時間（ミリ秒）
    pub appear_ms: u32,
    /// 難易度しきい値 1（これ以上でサイズ縮小）
    pub threshold_1: u32,
    /// 難易度しきい値 2（これ以上でさらに縮小）
    pub threshold_2: u32,
    /// 各段階のターゲットサイズ [easy, normal, hard]（dp 単位）
    pub target_sizes: [f32; 3],
}

impl Default for GameRule {
    fn default() -> Self {
        Self {
            duration_secs: 60,
            appear_ms:     1500,
            threshold_1:   10,
            threshold_2:   20,
            target_sizes:  [96.0, 68.0, 50.0],
        }
    }
}

// ─────────────────────────────────────────────
//  GameState — ゲームの内部状態
// ─────────────────────────────────────────────
#[derive(Debug, Clone, PartialEq)]
pub enum Phase {
    Idle,
    Playing,
    GameOver,
}

#[derive(Debug)]
pub struct GameState {
    pub phase:     Phase,
    pub score:     u32,
    pub time_left: u32,  // 残り秒数
    pub rule:      GameRule,
}

impl GameState {
    fn new(rule: GameRule) -> Self {
        Self {
            phase:     Phase::Idle,
            score:     0,
            time_left: rule.duration_secs,
            rule,
        }
    }

    /// 現スコアに対応するターゲットサイズ（dp）を返す
    pub fn current_target_size(&self) -> f32 {
        if self.score < self.rule.threshold_1 {
            self.rule.target_sizes[0]
        } else if self.score < self.rule.threshold_2 {
            self.rule.target_sizes[1]
        } else {
            self.rule.target_sizes[2]
        }
    }

    /// 難易度ラベル（0=ふつう, 1=むずかしい, 2=すごい）
    pub fn difficulty_level(&self) -> u8 {
        if self.score < self.rule.threshold_1 {
            0
        } else if self.score < self.rule.threshold_2 {
            1
        } else {
            2
        }
    }
}

// ─────────────────────────────────────────────
//  グローバルステート（Mutex で保護）
// ─────────────────────────────────────────────
static STATE: Mutex<Option<GameState>> = Mutex::new(None);

fn with_state<F, T>(f: F) -> T
where
    F: FnOnce(&mut GameState) -> T,
{
    let mut guard = STATE.lock().expect("mutex poisoned");
    let state = guard.as_mut().expect("engine not initialised — call engine_init first");
    f(state)
}

// ─────────────────────────────────────────────
//  C ABI 公開関数
// ─────────────────────────────────────────────

/// エンジン初期化。
/// `rule_json`: GameRule の JSON 文字列（NULL なら既定値を使用）
/// 戻り値: 0 = 成功, -1 = JSON パースエラー
#[no_mangle]
pub extern "C" fn engine_init(rule_json: *const c_char) -> c_int {
    let rule = if rule_json.is_null() {
        GameRule::default()
    } else {
        let cstr = unsafe { CStr::from_ptr(rule_json) };
        match serde_json::from_str::<GameRule>(cstr.to_str().unwrap_or("")) {
            Ok(r) => r,
            Err(_) => return -1,
        }
    };

    let mut guard = STATE.lock().expect("mutex poisoned");
    *guard = Some(GameState::new(rule));
    0
}

/// ゲーム開始（IDLE → PLAYING）
#[no_mangle]
pub extern "C" fn engine_start() {
    with_state(|s| {
        s.phase     = Phase::Playing;
        s.score     = 0;
        s.time_left = s.rule.duration_secs;
    });
}

/// 1 秒ティック。Flutter の Timer.periodic(1s) から呼ぶ。
/// 戻り値: 残り秒数（0 になったらゲームオーバー）
#[no_mangle]
pub extern "C" fn engine_tick() -> c_int {
    with_state(|s| {
        if s.phase != Phase::Playing {
            return s.time_left as c_int;
        }
        if s.time_left > 0 {
            s.time_left -= 1;
        }
        if s.time_left == 0 {
            s.phase = Phase::GameOver;
        }
        s.time_left as c_int
    })
}

/// ターゲットをタップしたときに呼ぶ。
/// 戻り値: タップ後のスコア（PLAYING でない場合は -1）
#[no_mangle]
pub extern "C" fn engine_on_hit() -> c_int {
    with_state(|s| {
        if s.phase != Phase::Playing {
            return -1;
        }
        s.score += 1;
        s.score as c_int
    })
}

/// 現在のスコアを返す
#[no_mangle]
pub extern "C" fn engine_get_score() -> c_int {
    with_state(|s| s.score as c_int)
}

/// 残り時間（秒）を返す
#[no_mangle]
pub extern "C" fn engine_get_time_left() -> c_int {
    with_state(|s| s.time_left as c_int)
}

/// フェーズ番号を返す（0=Idle, 1=Playing, 2=GameOver）
#[no_mangle]
pub extern "C" fn engine_get_phase() -> c_int {
    with_state(|s| match s.phase {
        Phase::Idle     => 0,
        Phase::Playing  => 1,
        Phase::GameOver => 2,
    })
}

/// 現在難易度に対応するターゲットサイズ（dp）を返す
#[no_mangle]
pub extern "C" fn engine_get_target_size() -> c_float {
    with_state(|s| s.current_target_size())
}

/// 難易度レベルを返す（0=ふつう, 1=むずかしい, 2=すごい）
#[no_mangle]
pub extern "C" fn engine_get_difficulty() -> c_int {
    with_state(|s| s.difficulty_level() as c_int)
}

/// 現在の GameRule を JSON 文字列として返す。
/// 呼び出し元は `engine_free_string` で解放すること。
#[no_mangle]
pub extern "C" fn engine_get_rule_json() -> *mut c_char {
    with_state(|s| {
        let json = serde_json::to_string(&s.rule).unwrap_or_default();
        CString::new(json).unwrap().into_raw()
    })
}

/// `engine_get_rule_json` が返したポインタを解放する
#[no_mangle]
pub extern "C" fn engine_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { drop(CString::from_raw(ptr)) };
    }
}

// ─────────────────────────────────────────────
//  ユニットテスト
// ─────────────────────────────────────────────
#[cfg(test)]
mod tests {
    use super::*;

    fn setup() {
        let rule = GameRule::default();
        let json = serde_json::to_string(&rule).unwrap();
        let cstr = CString::new(json).unwrap();
        assert_eq!(engine_init(cstr.as_ptr()), 0);
    }

    #[test]
    fn test_initial_state() {
        setup();
        assert_eq!(engine_get_phase(), 0);  // Idle
        assert_eq!(engine_get_score(), 0);
        assert_eq!(engine_get_time_left(), 60);
    }

    #[test]
    fn test_game_flow() {
        setup();
        engine_start();
        assert_eq!(engine_get_phase(), 1);  // Playing

        // ヒット → スコア加算
        assert_eq!(engine_on_hit(), 1);
        assert_eq!(engine_on_hit(), 2);
        assert_eq!(engine_get_score(), 2);

        // ティック × 60 → ゲームオーバー
        for _ in 0..60 {
            engine_tick();
        }
        assert_eq!(engine_get_phase(), 2);  // GameOver
    }

    #[test]
    fn test_difficulty_scaling() {
        setup();
        engine_start();

        // easy: score 0〜9
        assert_eq!(engine_get_difficulty(), 0);
        assert!((engine_get_target_size() - 96.0).abs() < 0.1);

        // normal: score 10〜19
        for _ in 0..10 { engine_on_hit(); }
        assert_eq!(engine_get_difficulty(), 1);
        assert!((engine_get_target_size() - 68.0).abs() < 0.1);

        // hard: score 20+
        for _ in 0..10 { engine_on_hit(); }
        assert_eq!(engine_get_difficulty(), 2);
        assert!((engine_get_target_size() - 50.0).abs() < 0.1);
    }

    #[test]
    fn test_rule_json_roundtrip() {
        setup();
        let ptr = engine_get_rule_json();
        assert!(!ptr.is_null());
        let json = unsafe { CStr::from_ptr(ptr).to_str().unwrap().to_owned() };
        engine_free_string(ptr);
        let rule: GameRule = serde_json::from_str(&json).unwrap();
        assert_eq!(rule.duration_secs, 60);
    }
}
