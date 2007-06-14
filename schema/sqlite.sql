CREATE TABLE jidmap (
    jidid INTEGER NOT NULL PRIMARY KEY,
    jid   VARCHAR(255) NOT NULL
);
CREATE INDEX jidmap_jid ON jidmap (jid);

CREATE TABLE history (
    jidid  INTEGER NOT NULL REFERENCES jidmap,
    time   TIMESTAMP NOT NULL,
    status VARCHAR(255) NOT NULL,
    avail  VARCHAR(10)  NOT NULL DEFAULT '',
    source VARCHAR(255) NOT NULL
);
CREATE INDEX history_jidid_time ON history (jidid, time);
