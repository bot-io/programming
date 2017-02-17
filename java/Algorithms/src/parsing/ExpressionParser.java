package parsing;

import java.util.ArrayList;

public class ExpressionParser {
	public static int parse(String expression) {
		int result = 0;
		ArrayList<String> values = new ArrayList<>();
		ArrayList<String> operations = new ArrayList<>();
		int length = expression.length();
		String temp = "";
		for (int i = 0; i < length; i++) {
			char c = expression.charAt(i);
			int val = (int) c;
			if (val >= 48 && val <= 57) {
				temp += c;
				System.out.println(temp);
				if (i == length - 1) {
					values.add(temp);
				}
			} else {
				if (!temp.equals("")) {
					values.add(temp);
				}
				temp = "";
				operations.add("" + c);
			}
		}

		System.out.print(values);
		System.out.print(operations);
		return result;
	}
}
