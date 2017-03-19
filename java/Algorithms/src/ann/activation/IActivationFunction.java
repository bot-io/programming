package ann.activation;

public interface IActivationFunction {
    double activate(double input);

    double derivative(double input);
}
