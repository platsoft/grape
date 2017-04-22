
-- Internal process to process data imports in ps_bgworker
SELECT grape.upsert_process('proc_process_data_import', 'Process Data Import', '{}'::JSON, 'DB', 'proc', 'Internal');

