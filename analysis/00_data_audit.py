from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parent
PARTICIPANT_PATH = ROOT / "data" / "participant.dta"
WEEKLY_PATH = ROOT / "data" / "weekly_long.dta"


def print_header(title: str) -> None:
    print(f"\n{title}")
    print("-" * len(title))


def load_data() -> tuple[pd.DataFrame, pd.DataFrame]:
    participant = pd.read_stata(PARTICIPANT_PATH)
    weekly = pd.read_stata(WEEKLY_PATH)
    return participant, weekly


def sample_flow(participant: pd.DataFrame) -> None:
    print_header("Sample Flow")
    print(f"participant shape: {participant.shape}")
    print(f"baseline frame: {len(participant):,}")
    print(f"randomized (recruited == 1): {(participant['recruited'] == 1).sum():,}")
    print(f"endline complete: {(participant['complete_endline'] == 1).sum():,}")
    print(f"follow-up complete: {(participant['complete_followup'] == 1).sum():,}")


def arm_structure(participant: pd.DataFrame) -> None:
    print_header("Arm Structure")
    recruited = participant.loc[participant["recruited"] == 1].copy()

    arm_counts = recruited["arm"].value_counts().sort_index().rename("n")
    print("arm counts:")
    print(arm_counts.to_string())

    schedule = (
        recruited.groupby("arm")[["treat_valence", "treat_dose_hi", "n_pol_slots"]]
        .agg(["mean", "min", "max"])
        .round(3)
    )
    print("\nassignment summary:")
    print(schedule.to_string())


def attrition(participant: pd.DataFrame) -> None:
    print_header("Attrition By Arm")
    recruited = participant.loc[participant["recruited"] == 1].copy()

    by_arm = recruited.groupby("arm").agg(
        n=("study_id", "size"),
        endline=("complete_endline", lambda s: (s == 1).sum()),
        followup=("complete_followup", lambda s: (s == 1).sum()),
        mean_last_week=("last_week_active", "mean"),
    )
    by_arm["endline_rate"] = by_arm["endline"] / by_arm["n"]
    by_arm["followup_rate_among_endline"] = by_arm["followup"] / by_arm["endline"]
    print(by_arm.round(3).to_string())


def balance_snapshot(participant: pd.DataFrame) -> None:
    print_header("Baseline Balance Snapshot")
    recruited = participant.loc[participant["recruited"] == 1].copy()

    cols = [
        "blk_gender",
        "blk_region",
        "blk_eng_hi",
        "blk_nat_hi",
        "t0_female",
        "t0_exam_score",
        "t0_nat_index",
        "t0_rs_index",
        "t0_cen_index",
        "t0_trust_foreign",
    ]
    means = recruited.groupby("arm")[cols].mean().round(3)
    print(means.to_string())


def weekly_structure(weekly: pd.DataFrame) -> None:
    print_header("Weekly Long Structure")
    print(f"weekly_long shape: {weekly.shape}")
    print(f"unique study_id: {weekly['study_id'].nunique():,}")
    print(f"weeks: {sorted(weekly['week'].dropna().unique().tolist())}")
    print(f"slots per week: {sorted(weekly['slot_wk'].dropna().unique().tolist())}")

    sched = (
        weekly.groupby("arm")["sched_political"].sum()
        / weekly.groupby("arm")["study_id"].nunique()
    ).round(3)
    print("\nscheduled political slots per participant by arm:")
    print(sched.to_string())

    means = weekly.groupby("arm")[
        [
            "wk_comply",
            "wk_read_min",
            "wk_vid_min",
            "wk_quiz_score",
            "wk_rate_interest",
            "wk_rate_cred",
            "wk_rate_similar",
        ]
    ].mean().round(3)
    print("\nslot-level means by arm:")
    print(means.to_string())


def main() -> None:
    participant, weekly = load_data()
    sample_flow(participant)
    arm_structure(participant)
    attrition(participant)
    balance_snapshot(participant)
    weekly_structure(weekly)


if __name__ == "__main__":
    main()
