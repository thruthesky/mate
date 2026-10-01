CREATE TABLE projects (
 id CHAR(32) PRIMARY KEY, name VARCHAR(120) NOT NULL, template VARCHAR(30) NOT NULL,
 created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3)
);
CREATE TABLE tasks (
 id CHAR(32) PRIMARY KEY, project_id CHAR(32) NOT NULL, title VARCHAR(200) NOT NULL,
 agent VARCHAR(20) NOT NULL, status VARCHAR(30) NOT NULL, session_id VARCHAR(100) NULL,
 created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3), updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
 FOREIGN KEY (project_id) REFERENCES projects(id)
);
CREATE TABLE environments (
 task_id CHAR(32) PRIMARY KEY, container_name VARCHAR(100) NOT NULL,
 workspace_volume VARCHAR(100) NOT NULL, session_volume VARCHAR(100) NOT NULL,
 FOREIGN KEY (task_id) REFERENCES tasks(id)
);
CREATE TABLE runs (
 id CHAR(32) PRIMARY KEY, task_id CHAR(32) NOT NULL, prompt TEXT NOT NULL,
 status VARCHAR(30) NOT NULL, cancel_requested BOOLEAN DEFAULT FALSE,
 result MEDIUMTEXT NULL, diff MEDIUMTEXT NULL, verification MEDIUMTEXT NULL,
 usage_json TEXT NULL, exit_code INT NULL, worker_id VARCHAR(80) NULL,
 created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3), started_at TIMESTAMP(3) NULL,
 finished_at TIMESTAMP(3) NULL,
 FOREIGN KEY (task_id) REFERENCES tasks(id), INDEX queue (status, created_at)
);
CREATE TABLE approvals (
 id CHAR(32) PRIMARY KEY, run_id CHAR(32) NOT NULL UNIQUE, status VARCHAR(20) NOT NULL DEFAULT 'pending',
 reason TEXT NOT NULL, decided_at TIMESTAMP(3) NULL,
 FOREIGN KEY (run_id) REFERENCES runs(id)
);
CREATE TABLE events (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, task_id CHAR(32) NOT NULL,
 run_id CHAR(32) NOT NULL, type VARCHAR(50) NOT NULL, data_json MEDIUMTEXT NOT NULL,
 created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
 FOREIGN KEY (task_id) REFERENCES tasks(id), FOREIGN KEY (run_id) REFERENCES runs(id),
 INDEX replay (task_id, id)
);
CREATE TABLE workers (
 id VARCHAR(80) PRIMARY KEY, info_json TEXT NOT NULL,
 heartbeat_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3)
);
INSERT INTO projects (id, name, template) VALUES ('00000000000000000000000000000001', '샘플 · Node 테스트 프로젝트', 'node-sample');
