import java.util.Date;

import ann.NeuralNetwork;
import parsing.ExpressionParser;

public class Main {

	public static void main(String[] args) {
		Date start = new Date();
		nnTest();
		Date end = new Date();
		long diffInMillies = end.getTime() - start.getTime();
		System.out.println("Computation duration: " + diffInMillies + " milliseconds.");
	}

	private static void parserTest() {
		// int[] a = { 8, 2, 5, 10, 9, 3, 7, 1, 4, 6 };
		/*
		 * Util.printArray(a); Quicksort.sort(a); Util.printArray(a);
		 */
		String expression = "((12+34)+10)/(56+78)";
		ExpressionParser.parse(expression);
	}

	private static void nnTest() {
		NeuralNetwork nn = new NeuralNetwork();
	}

}
