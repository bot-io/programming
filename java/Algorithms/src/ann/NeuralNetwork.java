package ann;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import logger.Logger;

public class NeuralNetwork {

    private Logger logger = new Logger();
    double learningRate = 0.1;
    List<INeuron> neurons = new ArrayList<>();

    // Input neurons
    InputNeuron i0 = new InputNeuron(0, "input0");
    InputNeuron i1 = new InputNeuron(0, "input1");

    // Middle layer neurons
    HiddenNeuron h0 = new HiddenNeuron("hidden0");
    HiddenNeuron h1 = new HiddenNeuron("hidden1");
    HiddenNeuron h2 = new HiddenNeuron("hidden2");
    HiddenNeuron h3 = new HiddenNeuron("hidden3");

    // Output neuron
    OutputNeuron o0 = new OutputNeuron("output");

    public NeuralNetwork() {

        // Middle layer neurons
        h0.addInputs(Arrays.asList(i0, i1));
        h1.addInputs(Arrays.asList(i0, i1));
        h2.addInputs(Arrays.asList(i0, i1));
        h3.addInputs(Arrays.asList(i0, i1));

        // Output neuron
        o0.addInputs(Arrays.asList(h0, h1, h2, h3));
        o0.setTarget(0);

        // Add all neurons to the network
        neurons.addAll(Arrays.asList(i0, i1, h0, h1, h2, h3, o0));

        train();

        i0.setInput(0);
        i1.setInput(1);
		o0.setTarget(0.66);

        print();
//
//         i0.setInput(0);
//         i1.setInput(0);
//        //
//         print();
    }

    public void train() {
        for (int i = 0; i < 1000; i += 2) {
            i0.setInput(0);
            i1.setInput(1);
            o0.setTarget(0.66);
            pulse(i);
//             i0.setInput(0);
//             i1.setInput(0);
//             o0.setTarget(1);
//             pulse(i + 1);
        }
    }

    public void pulse(int count) {
        logger.log("Activating network, count " + count);
        activate();
        print();
        logger.log("Adjusting weights for network: ");
        adjustWeights();
        print();
    }

    public void activate() {
        for (int i = 2; i < neurons.size(); i++) {
            INeuron n = neurons.get(i);
            n.activate();
        }
    }

    public void adjustWeights() {
        OutputNeuron n = (OutputNeuron) neurons.get(neurons.size() - 1);
        n.adjustWeights();
    }

    public void print() {
        logger.log("\nNetwork state: ");
        for (int i = 0; i < neurons.size(); i++) {
            INeuron n = neurons.get(i);
            logger.log(n.toString());
        }
    }
}
