# Cronk: a cron-json translator

> [!IMPORTANT]
> **Attending the OpenSSF Scorecard Supply-Chain Security Workshop?**
> Start here: **[`WORKSHOP.md`](WORKSHOP.md)** for the step-by-step hands-on exercises and checkpoint guide.
> Instructors can refer to **[`docs/INSTRUCTOR_GUIDE.md`](docs/INSTRUCTOR_GUIDE.md)**.

---

_This repository is an educational project for learning software supply-chain security with OpenSSF Scorecard and SLSA. It is meant for demonstrative purposes and should not be used in production!_

_All project backstory beyond this point is fictional!_

---

- **Student:** Alice Doe (`@nebraska-dev`), 2018Q4
- **Course:** CS 101: Introduction to Systems & Automation @ Cottonwood University _(Cottonwood is the Nebraska state tree)_

Cronk allows developers to convert files between the `crontab` and `json` formats.

## Project Structure

- `src/cronk/`: Python package for converting between `crontab` and `json` schedules.
- `src/cronk-helper/`: Small C CLI helper that prints the standard 5-field `crontab` syntax banner (`bin/cronk-helper`).
- `tests/`: Unit tests for `cron_to_json` and `json_to_cron`.

## To-do

- Add i18n of periodicity via Babel
