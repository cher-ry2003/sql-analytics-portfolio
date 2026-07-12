"""Run all SQL portfolio queries locally using DuckDB.

No database setup required — DuckDB runs in-process and reads
the CSV files directly from the datasets/ directory.

Usage:
    pip install duckdb
    python run_queries.py [section]

    Examples:
        python run_queries.py                 # run all sections
        python run_queries.py window          # 01-window-functions
        python run_queries.py cohort          # 02-cohort-retention
        python run_queries.py funnel          # 03-funnel-analysis
        python run_queries.py quality         # 04-data-quality-checks
"""
import sys
import pathlib
import duckdb

ROOT    = pathlib.Path(__file__).parent
DS      = ROOT / "datasets"

SECTIONS = {
    "window":  ROOT / "01-window-functions" / "queries.sql",
    "cohort":  ROOT / "02-cohort-retention" / "queries.sql",
    "funnel":  ROOT / "03-funnel-analysis"  / "queries.sql",
    "quality": ROOT / "04-data-quality-checks" / "queries.sql",
}


def load_data(con):
    con.execute(f"""
        CREATE OR REPLACE TABLE orders    AS SELECT * FROM read_csv_auto('{DS}/orders.csv');
        CREATE OR REPLACE TABLE customers AS SELECT * FROM read_csv_auto('{DS}/customers.csv');
        CREATE OR REPLACE TABLE events    AS SELECT * FROM read_csv_auto('{DS}/events.csv');
    """)


def run_section(con, name, path):
    sql = path.read_text()
    statements = [s.strip() for s in sql.split(";") if s.strip() and not s.strip().startswith("--")]
    for i, stmt in enumerate(statements, 1):
        first_comment = next(
            (l.lstrip("- ") for l in sql.split(stmt)[0].split("\n")
             if l.strip().startswith("-- ") and len(l.strip()) > 4), f"Query {i}"
        )
        title = first_comment.strip().rstrip(".")[:70]
        print(f"\n{'='*72}")
        print(f"  {name.upper()} — {title}")
        print(f"{'='*72}")
        try:
            result = con.execute(stmt).fetchdf()
            print(result.to_string(index=False, max_rows=15))
        except Exception as e:
            print(f"  ERROR: {e}")


def main():
    filter_key = sys.argv[1].lower() if len(sys.argv) > 1 else None
    sections   = {
        k: v for k, v in SECTIONS.items()
        if filter_key is None or k.startswith(filter_key)
    }

    if not sections:
        print(f"Unknown section '{filter_key}'. Choose: {', '.join(SECTIONS)}")
        sys.exit(1)

    # Generate datasets if missing
    if not (DS / "orders.csv").exists():
        print("Datasets not found — generating now...")
        import subprocess, sys as _sys
        subprocess.run([_sys.executable, str(DS / "generate.py")], check=True)

    con = duckdb.connect()
    load_data(con)
    print(f"\nLoaded: {con.execute('SELECT COUNT(*) FROM orders').fetchone()[0]:,} orders | "
          f"{con.execute('SELECT COUNT(*) FROM customers').fetchone()[0]:,} customers | "
          f"{con.execute('SELECT COUNT(*) FROM events').fetchone()[0]:,} events")

    for name, path in sections.items():
        run_section(con, name, path)

    print(f"\n{'='*72}")
    print("  Done.")


if __name__ == "__main__":
    main()
