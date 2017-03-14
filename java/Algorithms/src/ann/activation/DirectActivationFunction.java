package ann.activation;

public class DirectActivationFunction implements IActivationFunction {

    @Override
    public double activate(double input) {
        return input;
    }

    @Override
    public double derivative(double input) {
        return 1;
    }

}
