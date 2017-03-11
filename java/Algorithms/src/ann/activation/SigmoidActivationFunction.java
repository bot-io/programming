package ann.activation;

import util.Util;

public class SigmoidActivationFunction implements IActivationFunction {

	@Override
	public double activate(double input) {
		return Util.sigmoid(input);
	}

}
