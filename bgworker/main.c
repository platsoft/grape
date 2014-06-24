
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <libpq-fe.h>
#include <pthread.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <dirent.h>


pid_t proc_find(const char* );
	

int threads_used[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0};
pthread_t threads[10];

struct schedule
{
	int schedule_id;
	int process_id;
	char *pg_function;
	char *param;
	int user_id;
};

struct thread_info 
{
	PGconn *conn;
	struct schedule *sched;
};

void rtrim(char **text);
int uid_find();

char *confHost = NULL;
char *confDBName = NULL;
char *confUser = NULL;
char *confPort = NULL;
char *confLogfile = NULL;

void rtrim(char **text)
{
	unsigned char *t = (unsigned char *)*text;
	unsigned char *p = t;

	while (*p != '\0')
		p++;
	p--;

	while (p > t && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r'))
		p--;
	if (p >= t)
		*(p+1) = '\0';
	else
		*p = '\0';
}

int readconf()
{
	FILE *fp;
	fp = fopen("ps_bgworker.conf", "r");
	if (!fp)
	{
		printf("Could not open configuration file ps_bgworker.conf\n");
		return -1;
	}

	if (confHost)
		free(confHost);
	if (confDBName)
		free(confDBName);
	if (confUser)
		free(confUser);
	if (confPort)
		free(confPort);
	if (confLogfile)
		free(confLogfile);

	confHost = (char *)calloc(1000, 1);
	confDBName = (char *)calloc(1000, 1);
	confUser = (char *)calloc(1000, 1);
	confPort = (char *)calloc(1000, 1);
	confLogfile = (char *)calloc(1000, 1);

	char *line = (char *)malloc(1024);
	char *p ;

	while (fgets(line, 1024, fp) )
	{
		p = strchr(line, '=');
		if (p == NULL)
			continue;
		*p = '\0';
		p++;
		if (p == '\0')
			continue;
		if (strstr(line, "host"))
			strcpy(confHost, p);
		else if (strstr(line, "dbname"))
			strcpy(confDBName, p);
		else if (strstr(line, "user"))
			strcpy(confUser, p);
		else if (strstr(line, "port"))
			strcpy(confPort, p);
		else if (strstr(line, "logfile"))
			strcpy(confLogfile, p);
	}

	rtrim(&confHost);
	rtrim(&confDBName);
	rtrim(&confUser);
	rtrim(&confPort);
	rtrim(&confLogfile);

	fclose(fp);
	return 0;
}

PGconn *open_db()
{
	PGconn *ret = NULL;
	char **keywords = (char **)malloc(4 * sizeof(char *));
	char **values = (char **)malloc(4 * sizeof(char *));

	readconf();

	keywords[0] = strdup("host");
	keywords[1] = strdup("dbname");
	keywords[2] = strdup("user");
	keywords[3] = strdup("port");
	keywords[4] = NULL;
	
	values[0] = strdup(confHost);
	values[1] = strdup(confDBName);
	values[2] = strdup(confUser);
	values[3] = strdup(confPort);
	values[4] = NULL;

	ret = PQconnectdbParams((const char*const*)keywords, (const char*const*)values, 1);

	free(values[0]);
	free(values[1]);
	free(values[2]);
	free(values[3]);
	free(keywords[0]);
	free(keywords[1]);
	free(keywords[2]);
	free(keywords[3]);

	free(values);
	free(keywords);

	if (PQstatus(ret) != CONNECTION_OK)
	{
		printf("ERROR opening connection %s\n", PQerrorMessage(ret));
		return NULL;
	}

	if (ret)
	{
		printf("Connection to server established\n");
	}
	else
	{
		printf("ERROR opening connection\n");
	}
	
	return ret;
}

void noticeProcessor(void *arg, const char *message)
{
	PGresult *res;

	struct thread_info *info = (struct thread_info *)arg;
	
	char *escaped = PQescapeLiteral(info->conn, message, strlen(message));

	if (!escaped)
	{
		printf("ERROR %s\n", PQerrorMessage(info->conn));
		return;
	}
	
	char *qry = (char *)malloc(1024 + strlen(escaped));

	sprintf(qry, "INSERT INTO grape.schedule_log (schedule_id, time, message) VALUES (%d, CURRENT_TIMESTAMP, %s)", info->sched->schedule_id, escaped);

	res = PQexec(info->conn, qry);
	if (res)
		PQclear(res);

	PQfreemem(escaped);
	free(qry);
}
void noticeReceiver(void *arg, const PGresult *res)
{
	PGresult *result;
	struct thread_info *info = (struct thread_info *)arg;
	char *qry = NULL;
	
	char *message_primary = PQresultErrorField(res, PG_DIAG_MESSAGE_PRIMARY);

	printf("NOTICE %s on %d\n", message_primary, info->sched->schedule_id);

	qry = (char *)malloc(110 + strlen(message_primary));

	sprintf(qry, "INSERT INTO grape.schedule_log (schedule_id, time, message) VALUES (%d, CURRENT_TIMESTAMP, '%s')", info->sched->schedule_id, message_primary);

	result = PQexec(info->conn, qry);
	if (result)
		PQclear(result);

	free(qry);
}


void *start_process(void *s)
{
	char *qry = (char *)malloc(1024);

	PGconn *conn = open_db();
	PGconn *notice_conn = open_db();
	struct schedule *sched = (struct schedule *)s;
	struct thread_info *info = (struct thread_info *) malloc(sizeof(struct thread_info));
	PGresult *result;
	pid_t tid;

	tid = syscall(SYS_gettid);
	info->conn = notice_conn;
	info->sched = sched;

	printf("Thread started to call grape.%s('%s'::JSON);\n", sched->pg_function, sched->param);

	sprintf(qry, "Starting %s (%s)", sched->pg_function, sched->param);
	noticeProcessor((void *)info, qry);
	
	sprintf(qry, "UPDATE grape.schedule SET pid=%d, status='Running' WHERE schedule_id=%d", tid, sched->schedule_id);
	result = PQexec(conn, qry);
	if (result)
		PQclear(result);

	sprintf(qry, "SELECT set_config('platlife.user_id', '%d', false)", sched->user_id);
	result = PQexec(conn, qry);
	if (result)
		PQclear(result);

	PQsetNoticeReceiver(conn, noticeReceiver, info);
	
	sprintf(qry, "SELECT grape.%s('%s'::JSON)", sched->pg_function, sched->param);
	printf("Query: [%s]\n", qry);
	result = PQexec(conn, qry);
	if (PQresultStatus(result) != 2)
	{
		//noticeProcessor((void *)info, PQresultErrorField(result, PG_DIAG_MESSAGE_PRIMARY));
		printf("ERROR: %s\n", PQresultErrorMessage(result));
		printf("ERROR %s\n", PQerrorMessage(info->conn));
		noticeProcessor((void *)info, PQresultErrorMessage(result));
		if (result)
			PQclear(result);

		sprintf(qry, "UPDATE grape.schedule SET status='Error' WHERE schedule_id=%d", sched->schedule_id);
		result = PQexec(conn, qry);
		if (result)
			PQclear(result);
	}
	else
	{
		if (result)
			PQclear(result);
		sprintf(qry, "UPDATE grape.schedule SET status='Completed' WHERE schedule_id=%d", sched->schedule_id);
		result = PQexec(conn, qry);
		if (result)	
			PQclear(result);
	}

	sprintf(qry, "UPDATE grape.schedule SET time_ended=CURRENT_TIMESTAMP WHERE schedule_id=%d", sched->schedule_id);
	result = PQexec(conn, qry);
	PQclear(result);
	
	sprintf(qry, "Done.");
	noticeProcessor((void *)info, qry);

	PQfinish(conn);
	PQfinish(notice_conn);
	
	free(qry);
	free(info);
	return NULL;
}

int check_thread_statuses()
{
	int c = 0;
	int i;
	for (i = 0; i < 10; i++)
	{
		if (threads_used[i] == 0)
			c++;
		else if (pthread_kill(threads[i], 0))
		{
			threads_used[i] = 0;
			c++;
		}
	}
	return c;
}

int main(int argc, char **argv)
{
	PGresult *result;
	PGresult *res;
	PGconn *conn = NULL;
	int i = 0, j = 0;
	struct schedule *sched;
	char qry[512];
	pid_t ppid;

	if ((ppid = proc_find("ps_bgworker")) > 0)
	{
		printf("%s is already running (%d)\n", "ps_bgworker", ppid);
		return 1;
	}

	if (argc > 1 && strcmp(argv[1], "-f") == 0)
	{
		//run in foreground
	}
	else
	{
		if (fork() > 0) return 0;
		setsid();
		signal (SIGHUP, SIG_IGN);
		fclose(stdin);
		fclose(stderr);

		readconf();

		freopen(confLogfile, "a", stdout);
		if (!stdout)
		{
			freopen("/tmp/ps_bgworker.log", "a", stdout);
		}
	}
	
	conn = open_db();
	
	while (1)
	{
		if (PQstatus(conn) == CONNECTION_BAD)
		{
			PQfinish(conn);
			conn = open_db();
		}

		if (check_thread_statuses() == 0)
		{
			printf("No threads available\n");
			sleep(3); 
			continue;
		}

		result = PQexec(conn, "SELECT grape.schedule.process_id, schedule_id, pg_function, param, grape.schedule.user_id FROM grape.schedule JOIN grape.process USING (process_id) WHERE time_started IS NULL AND time_sched <= CURRENT_TIMESTAMP AND grape.schedule.process_id NOT IN (SELECT ss.process_id FROM grape.schedule AS ss WHERE ss.time_ended IS NULL AND ss.time_started IS NOT NULL AND ss.schedule_id != grape.schedule.schedule_id) LIMIT 1");

		if (PQresultStatus(result) == PGRES_TUPLES_OK)
		{
			for (i = 0; i < PQntuples(result); i++)
			{
				sched = (struct schedule *)malloc(sizeof(struct schedule));
				sched->process_id = atoi(PQgetvalue(result, i, 0));
				sched->schedule_id = atoi(PQgetvalue(result, i, 1));
				sched->pg_function = strdup(PQgetvalue(result, i, 2));
				sched->param = strdup(PQgetvalue(result, i, 3));
				sched->user_id = atoi(PQgetvalue(result, i, 4));

				
				for (j = 0; j < 10 && threads_used[j]; j++);
				if (j >= 10)
				{
					printf("No threads available\n");
					continue;
				}

				sprintf(qry, "UPDATE grape.schedule SET time_started=CURRENT_TIMESTAMP WHERE grape.schedule.schedule_id=%d", sched->schedule_id);
				res = PQexec(conn, qry);
				if (res)
					PQclear(res);

				printf("Spawning thread for schedule %d\n", sched->schedule_id);

				pthread_create(&threads[j], NULL, start_process, sched);

				threads_used[j] = threads[j];
				
			}
			PQclear(result);
		}

		sleep(5);
	}
}


pid_t proc_find(const char* name) 
{
	DIR* dir;
	struct dirent* ent;
	char buf[512];

	long  pid;
	char pname[100] = {0,};
	char state;
	FILE *fp=NULL; 
	long mypid;
	long myuid;

	myuid = getuid();
	mypid = getpid();

	if (!(dir = opendir("/proc"))) 
	{
		perror("can't open /proc");
		return -1;
	}

	while((ent = readdir(dir)) != NULL) 
	{
		long lpid = atol(ent->d_name);
		if (lpid < 0)
			continue;
		snprintf(buf, sizeof(buf), "/proc/%ld/stat", lpid);
		fp = fopen(buf, "r");

		if (fp) 
		{
			if ( (fscanf(fp, "%ld (%[^)]) %c", &pid, pname, &state)) != 3 )
			{
				printf("fscanf failed \n");
				fclose(fp);
				closedir(dir);
				return -1; 
			}
			if (!strcmp(pname, name) && mypid != lpid) 
			{
				int targetUid;
				targetUid = uid_find(mypid, pid);

				if (targetUid < 0 || targetUid == myuid)
				{
					fclose(fp);
					closedir(dir);
					return (pid_t)lpid;
				}
			}
			fclose(fp);
		}
	}


	closedir(dir);
	return -1;
}


int uid_find(long mypid, long pid)
{
	char* pidPath = malloc(100);
	sprintf( pidPath, "/proc/%ld/status", pid);

	int uid;
	uid = 0;

	FILE *fp;
	fp = fopen(pidPath, "r");
	if (!fp)
	{
		printf("Could not open status file %s\n", pidPath);
		return -1;
	}

	char *uidString = (char *)malloc(1024);
	char *line = (char *)malloc(1024);
	char *p ;

	while (fgets(line, 1024, fp) != NULL )
	{
		p = strchr(line, ':');
		if (p == NULL)
			continue;
		*p = '\0';
		p++;
		if (p == '\0')
			continue;
		if (strstr(line, "Uid"))
		{
			strcpy(uidString, p);
			sscanf( uidString, " %d  %*d %*d %*d", &uid );
		}
	}

	fclose(fp);

	free(pidPath);
	free(uidString);
	free(line);
	return uid;
}
