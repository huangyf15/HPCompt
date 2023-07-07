#include <iostream>
#include <fstream>
#include <Windows.h>
#include <string>
#include <time.h>
#include <chrono>
using namespace std;
using namespace chrono;

string getCurrTimeStr();

int main()
{
	static string testName = "cycle strategy effect on matMulti_CPU";
	static string opFileName = "out_matMulti_CPU_w1000.log";
	static string timeString = getCurrTimeStr();
	const int n = 1000;

	ofstream fout(opFileName);
	streambuf* oldclog;
	oldclog = clog.rdbuf(fout.rdbuf());

	clog << "Title: " << testName << "\n"
		<< "Current time: " << timeString << " ms\n\n"
		<< "Init matrices: Width = " << n << "\n" << endl;

	static int matA[n][n] = { 0 };
	static int matB[n][n] = { 0 };
	static int matC[n][n] = { 0 };
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			if (i == j)
			{
				matA[i][j] = i;
				matB[j][i] = j;
			}
			else
			{
				matA[i][j] = 0;
				matB[j][i] = 0;
			}
		}
	}

	// cycle by column
	auto start = system_clock::now();
	int cij = 0.0;
	for (int j = 0; j < n; j++)
	{
		for (int i = 0; i < n; i++)
		{
			cij = 0.0;
			for (int k = 0; k < n; k++)
			{
				cij += matA[i][k] * matB[k][j];
			}
			matC[i][j] = cij;
		}
	}
	auto end = system_clock::now();
	auto duration = duration_cast<microseconds>(end - start);
	clog << "*** Cycle by column: cost "
		<< double(duration.count()) * microseconds::period::num \
		/ microseconds::period::den
		<< " s" << endl;
	for (int i = 0; i < 10; i++)
	{
		for (int j = 0; j < 10; j++)
		{
			clog << matC[i][j] << "\t";
		}
		clog << endl;
	}

	// cycle by row
	start = system_clock::now();
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			cij = 0.0;
			for (int k = 0; k < n; k++)
			{
				cij += matA[i][k] * matB[k][j];
			}
			matC[i][j] = cij;
		}
	}
	end = system_clock::now();
	duration = duration_cast<microseconds>(end - start);
	clog << "*** Cycle by row: cost "
		<< double(duration.count()) * microseconds::period::num \
		/ microseconds::period::den
		<< " s" << endl;
	for (int i = 0; i < 10; i++)
	{
		for (int j = 0; j < 10; j++)
		{
			clog << matC[i][j] << "\t";
		}
		clog << endl;
	}

	// cycle by row (global var)
	start = system_clock::now();
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			matC[i][j] = 0.0;
			for (int k = 0; k < n; k++)
			{
				matC[i][j] += matA[i][k] * matB[k][j];
			}
		}
	}
	end = system_clock::now();
	duration = duration_cast<microseconds>(end - start);
	clog << "*** Cycle by row (global var): cost "
		<< double(duration.count()) * microseconds::period::num \
		/ microseconds::period::den
		<< " s" << endl;
	for (int i = 0; i < 10; i++)
	{
		for (int j = 0; j < 10; j++)
		{
			clog << matC[i][j] << "\t";
		}
		clog << endl;
	}

}

string getCurrTimeStr()
{
	system_clock::time_point t = system_clock::now();
	milliseconds ms = duration_cast<milliseconds>(t.time_since_epoch());
	char time_string[128];
	time_t curtm = time(NULL);
	struct tm tm;
	localtime_s(&tm, &curtm);
	sprintf_s(time_string, "%04d-%02d-%02d %02d:%02d:%02d %03lld", \
		tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, \
		tm.tm_min, tm.tm_sec, ms.count() % 1000);
	return time_string;
}