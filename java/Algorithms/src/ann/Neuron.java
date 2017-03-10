package ann;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import util.Util;

public class Neuron {

    public Neuron(double output) {
        this.cachedOutput = output;
        this.name = UUID.randomUUID().toString();
    }

    public Neuron(double output, String name) {
        this(output);
        this.name = name;
    }

    public String name = "";
    public double bias;
    public double cachedOutput;

    private double correctionDelta;

    public Map<Neuron, Double> weights = new HashMap<>();

    public double activate() {
        // Put the input sum through the decided activation function
        cachedOutput = Util.sigmoid(getInputsSum());

        return cachedOutput;
    }

    private double getInputsSum() {
        double result = 0;
        // Sum all incoming neurons outputs multiplied by the
        // connection weight
        for (Neuron n : weights.keySet()) {
            result += weights.get(n) * n.cachedOutput;
        }

        return result;
    }

    /*
     * Get the global correction delta for the specific neuron
     */
    public void calculateCorrectionDelta(double target) {
        double error = target - cachedOutput;
        System.out.println();
        this.correctionDelta = Util.sigmoidDerivative(getInputsSum()) * error;
        System.out.println(name + ": Delta output sum: " + correctionDelta);
    }

    public void adjustWeights() {
        // Use the global correction delta, to calculate the specific correction delta for each weight
        for (Neuron n : weights.keySet()) {
            double weightCorrectionDelta = weights.get(n) * correctionDelta;
            double newWeight = weights.get(n) + weightCorrectionDelta;
            weights.put(n, newWeight);
            n.adjustWeights(weightCorrectionDelta);
        }
    }

    public void adjustWeights(double correctionDelta) {
        // Use the global correction delta, to calculate the specific correction delta for each weight
        for (Neuron n : weights.keySet()) {
            double weightCorrectionDelta = n.cachedOutput * correctionDelta;
            System.out.println(name + ": Adjusting weight " + weights.get(n) + ", with " + n.cachedOutput + "*"
                    + correctionDelta);
            double newWeight = weights.get(n) + weightCorrectionDelta;
            System.out.println(name + ": Old weight " + weights.get(n) + ", new weight " + newWeight);
            weights.put(n, newWeight);
        }
    }

    @Override
    public String toString() {
        String result = name + ": ";

        if (!weights.isEmpty()) {
            result += "Weights: ";
            for (Neuron n : weights.keySet()) {
                result += weights.get(n) + ", ";
            }
        }

        result += "output: " + cachedOutput;

        return result;
    }

}
