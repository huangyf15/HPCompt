#include <iostream>
#include <fstream>
#include <Windows.h>
#include <string>
#include <time.h>
#include <chrono>
using namespace std;
using namespace chrono;

string getCurrTimeStr();

void mulMatrixOnHost(int* M, int* N, int* P, int width);
void mulMatrixOnHost_inline(int* M, int* N, int* P, int width);

int map2MatrixEleNo(int rowNo, int colNo, int height){	return rowNo * height + colNo;}
inline int map2MatrixEleNo_inline(int rowNo, int colNo, int height){	return rowNo * height + colNo;}

void printResMatrix(string info, float seconds, int* mat, int width);

int main()
{
	static string testName = "inline func effect on matMulti_func_CPU";
	static string opFileName = "out_matMulti_func_CPU_w1000.log";
	static string timeString = getCurrTimeStr();
	const int width = 1000;

	ofstream fout(opFileName);
	streambuf* oldclog;
	oldclog = clog.rdbuf(fout.rdbuf());
	
	clog << "Title: " << testName << "\n"
			 << "Current time: " << timeString << " ms\n\n"
			 << "Init matrices: Width = " << width << "\n" << endl;

	int* matA = new int[width * width]();
	int* matB = new int[width * width]();
	int* matC = new int[width * width]();
	for (int i = 0; i < width; i++)
	{
		for (int j = 0; j < width; j++)
		{
			if (i == j)
			{
				matA[map2MatrixEleNo(i, j, width)] = i;
				matB[map2MatrixEleNo(i, j, width)] = i;
				matC[map2MatrixEleNo(i, j, width)] = i;
			}
			else
			{
				matA[map2MatrixEleNo(i, j, width)] = 0;
				matB[map2MatrixEleNo(i, j, width)] = 0;
				matC[map2MatrixEleNo(i, j, width)] = 0;
			}
		}
	}

	// cycle using 1D array (no inline)
	string info_1 = "1D array (no inline)";
	auto start = system_clock::now();
	mulMatrixOnHost(matA, matB, matC, width);
	auto end = system_clock::now();
	auto duration = duration_cast<microseconds>(end - start);
	float seconds = float(duration.count()) * microseconds::period::num \
		/ microseconds::period::den;
	printResMatrix(info_1, seconds, matC, width);

	// cycle using 1D array (w inline)
	string info_2 = "1D array (with inline)";
	start = system_clock::now();
	mulMatrixOnHost_inline(matA, matB, matC, width);
	end = system_clock::now();
	duration = duration_cast<microseconds>(end - start);
	seconds = float(duration.count()) * microseconds::period::num \
		/ microseconds::period::den;
	printResMatrix(info_2, seconds, matC, width);

	delete []matA, matB, matC;

}

string getCurrTimeStr()
{
	system_clock::time_point t = system_clock::now();
	milliseconds ms = duration_cast<milliseconds>(t.time_since_epoch());
	char time_string[128];
	time_t curtm = time(NULL);
	struct tm tm;
	localtime_s(&tm, &curtm);
	sprintf_s(time_string, "%04d-%02d-%02d %02d:%02d:%02d %03lld ", \
		tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, \
		tm.tm_min, tm.tm_sec, ms.count() % 1000);
	return time_string;
}

void mulMatrixOnHost(int* M, int* N, int* P, int width)
{
	for (int i = 0; i < width; ++i)
	{
		for (int j = 0; j < width; ++j)
		{
			int sum = 0;
			for (int k = 0; k < width; ++k)
			{
				sum += M[map2MatrixEleNo(i, k, width)] * \
					N[map2MatrixEleNo(k, j, width)];
			}
			P[map2MatrixEleNo(i, j, width)] = sum;
		}
	}
}

void mulMatrixOnHost_inline(int* M, int* N, int* P, int width)
{
	for (int i = 0; i < width; ++i)
	{
		for (int j = 0; j < width; ++j)
		{
			int sum = 0;
			for (int k = 0; k < width; ++k)
			{
				sum += M[map2MatrixEleNo_inline(i, k, width)] * \
					N[map2MatrixEleNo_inline(k, j, width)];
			}
			P[map2MatrixEleNo_inline(i, j, width)] = sum;
		}
	}
}

void printResMatrix(string info, float seconds, int* mat, int width)
{
	clog << "*** Using " << info << ": cost "
		<< seconds << " s" << endl;
	int outputWidth = min(width, 10);
	for (int i = 0; i < outputWidth; i++)
	{
		for (int j = 0; j < outputWidth; j++)
		{
			clog << mat[map2MatrixEleNo(i, j, width)] << "\t";
		}
		clog << endl;
	}
}