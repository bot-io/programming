package util;

import java.math.BigDecimal;
import java.math.RoundingMode;

public class Util {
	public static void printArray(int[] array) {
		System.out.print("[");
		for (int i = 0; i < array.length; i++) {
			System.out.print(array[i]);
			if (i < array.length - 1) {
				System.out.print(", ");
			}
		}
		System.out.print("]\n");
	}

	public static void printArrayEmphasized(int[] array, int[] emphasizedIndicesArray) {
		System.out.print("[");
		for (int i = 0; i < array.length; i++) {
			if (arrayContains(emphasizedIndicesArray, i)) {
				System.out.print("*");
			}
			System.out.print(array[i]);
			if (i < array.length - 1) {
				System.out.print(", ");
			}
		}
		System.out.print("]\n");
	}

	public static boolean arrayContains(int[] array, int element) {
		for (int i = 0; i < array.length; i++) {
			if (array[i] == element) {
				return true;
			}
		}
		return false;
	}

	public static double sigmoid(double x) {
		return 1 / (1 + Math.exp(-x));
	}

	public static double sigmoidDerivative(double x) {
		return Math.exp(-x) / Math.pow((1 + Math.exp(-x)), 2);
	}

	public static double toPrecision(int precision, double input) {
		return BigDecimal.valueOf(input).setScale(precision, RoundingMode.HALF_UP).doubleValue();
	}
}
