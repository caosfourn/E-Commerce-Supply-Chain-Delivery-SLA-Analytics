"""Read-only mart access; no business rules and no CSV fallback."""
import os
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

def get_engine():
    connection_string = os.getenv('OLIST_CONNECTION_STRING') or (
        f"DRIVER={{{os.getenv('OLIST_DRIVER', 'ODBC Driver 18 for SQL Server')}}};"
        f"SERVER={os.getenv('OLIST_SERVER', 'localhost')};"
        f"DATABASE={os.getenv('OLIST_DATABASE', 'olist')};"
        'Trusted_Connection=yes;Encrypt=yes;'
        f"TrustServerCertificate={os.getenv('OLIST_TRUST_CERTIFICATE', 'yes')};"
    )
    engine = create_engine(URL.create('mssql+pyodbc', query={'odbc_connect': connection_string}),
                           connect_args={'timeout': 5})
    try:
        with engine.connect() as connection:
            connection.execute(text('SELECT 1'))
    except Exception:
        engine.dispose()
        raise RuntimeError('Cannot connect to SQL Server. Check OLIST_SERVER, service, '
                           'ODBC driver and credentials. No CSV fallback is used.') from None
    return engine

def read_mart(name,engine):
    if name not in {'sales','customer','logistics','seller','category'}:
        raise ValueError('Unknown mart')
    with engine.connect() as connection:
        return pd.read_sql_query(text(f'SELECT * FROM mart.vw_{name}'),connection)
